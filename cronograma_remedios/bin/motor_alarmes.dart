import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

// Motor desktop comum ao Linux e ao Windows.
// É compilado em executável independente do Flutter.
// --evento <banco> <id> <data yyyy-MM-dd> <horario> <nome> <quantidade>
Future<void> main(List<String> args) async {
  if (args.length == 7 && args.first == '--evento') {
    await executarInteracao(args);
    return;
  }
  if (args.length != 2 || args.first != '--banco') {
    stderr.writeln('Uso: motor_alarmes --banco CAMINHO_DO_SQLITE');
    exitCode = 2;
    return;
  }
  final arquivo = File(args[1]);
  if (!arquivo.existsSync()) {
    stderr.writeln('Banco de dados não encontrado: ${arquivo.path}');
    exitCode = 2;
    return;
  }
  final trava = File('${arquivo.path}.motor.lock');
  RandomAccessFile? bloqueio;
  try {
    bloqueio = trava.openSync(mode: FileMode.write);
    bloqueio.lockSync(FileLock.exclusive); // Evita dois motores simultâneos.
  } catch (_) {
    stderr.writeln('Não foi possível obter a trava do motor.');
    return;
  }
  try {
    while (true) {
      try {
        verificarEventos(arquivo.path);
      } catch (erro) {
        stderr.writeln('Falha de verificação: $erro');
      }
      // A espera não executa CPU; o motor acorda para observar novos cadastros.
      await Future<void>.delayed(const Duration(seconds: 15));
    }
  } finally {
    bloqueio.unlockSync();
    bloqueio.closeSync();
  }
}

String dois(int numero) => numero.toString().padLeft(2, '0');
String isoData(DateTime data) => '${data.year}-${dois(data.month)}-${dois(data.day)}';
DateTime semHora(DateTime data) => DateTime(data.year, data.month, data.day);
int diasEntre(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day)
    .difference(DateTime.utc(a.year, a.month, a.day)).inDays;

void criarTabelas(Database banco) {
  banco.execute('PRAGMA busy_timeout = 5000');
  banco.execute('''CREATE TABLE IF NOT EXISTS motor_eventos (
    chave TEXT PRIMARY KEY, criado_em TEXT NOT NULL
  )''');
  banco.execute('''CREATE TABLE IF NOT EXISTS adiamentos (
    chave_dose TEXT PRIMARY KEY, novo_horario TEXT NOT NULL,
    atualizado_em TEXT NOT NULL
  )''');
}

bool registrado(Database banco, String chave) => banco.select(
  'SELECT 1 FROM registros WHERE chave = ? LIMIT 1', [chave],
).isNotEmpty;

bool reservar(Database banco, String chave) {
  banco.execute('INSERT OR IGNORE INTO motor_eventos(chave,criado_em) VALUES (?,?)',
      [chave, DateTime.now().toIso8601String()]);
  return banco.updatedRows > 0;
}

void verificarEventos(String caminho) {
  final banco = sqlite3.open(caminho);
  try {
    criarTabelas(banco);
    final agora = DateTime.now();
    // Verifica a data anterior também, para adiamentos que cruzem a meia-noite.
    final datas = [-1, 0, 1]
        .map((d) => DateTime(agora.year, agora.month, agora.day + d));
    final medicamentos = banco.select('''
      SELECT id, nome, quantidade, horarios, data_inicio, intervalo_dias
      FROM medicamentos
    ''');
    for (final med in medicamentos) {
      final id = med['id'] as int;
      final nome = med['nome'] as String;
      final quantidade = med['quantidade'] as String;
      final inicio = DateTime.parse(med['data_inicio'] as String);
      final intervalo = med['intervalo_dias'] as int;
      if (intervalo < 1) continue;
      final horarios = (med['horarios'] as String).split(',');
      for (final data in datas) {
        final diferenca = diasEntre(inicio, data);
        if (diferenca < 0 || diferenca % intervalo != 0) continue;
        for (final horarioBruto in horarios) {
          final horario = horarioBruto.trim();
          final partes = horario.split(':');
          if (partes.length != 2) continue;
          final dose = DateTime(data.year, data.month, data.day,
              int.parse(partes[0]), int.parse(partes[1]));
          final chaveDose = '${id}_${isoData(data)}_$horario';
          if (registrado(banco, chaveDose)) continue;
          final adiamentos = banco.select(
              'SELECT novo_horario FROM adiamentos WHERE chave_dose = ?', [chaveDose]);
          final adiado = adiamentos.isNotEmpty;
          final proximo = adiado
              ? DateTime.parse(adiamentos.first['novo_horario'] as String)
              : dose;
          if (!adiado) {
            final inicioLembrete = dose.subtract(const Duration(minutes: 15));
            final segundos = agora.difference(inicioLembrete).inSeconds;
            if (segundos >= 0 && segundos < 75 &&
                reservar(banco, '${chaveDose}_lembrete')) {
              avisoSimples('Lembrete de medicamento',
                  '$nome: faltam 15 minutos para $horario.');
            }
          }
          final atraso = agora.difference(proximo).inSeconds;
          if (atraso < 0 || atraso >= 75) continue;
          final evento = '${chaveDose}_${adiado ? proximo.toIso8601String() : 'original'}';
          if (!reservar(banco, evento)) continue;
          // O diálogo executa num processo separado. O motor não fica bloqueado.
          Process.start(Platform.resolvedExecutable, [
            '--evento', caminho, '$id', isoData(data), horario, nome, quantidade,
          ], mode: ProcessStartMode.detachedWithStdio).then((processo) {
            processo.stdout.drain<void>();
            processo.stderr.drain<void>();
          }).catchError((Object erro) {
            stderr.writeln('Falha ao iniciar interação: $erro');
          });
        }
      }
    }
    // Mantém a tabela de eventos pequena (30 dias de retenção).
    final limite = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    banco.execute('DELETE FROM motor_eventos WHERE criado_em < ?', [limite]);
  } finally {
    banco.dispose();
  }
}

Future<void> avisoSimples(String titulo, String mensagem) async {
  if (Platform.isLinux) {
    await Process.run('notify-send', [titulo, mensagem]);
  } else if (Platform.isWindows) {
    // Notificação visual transitória. Não permanece executando.
    final script = r'''Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$n=New-Object System.Windows.Forms.NotifyIcon
$n.Icon=[System.Drawing.SystemIcons]::Information
$n.Visible=$true
$n.BalloonTipTitle=$args[0]
$n.BalloonTipText=$args[1]
$n.ShowBalloonTip(5000)
Start-Sleep -Seconds 6
$n.Dispose()''';
    await powershell(script, [titulo, mensagem]);
  }
}

Future<ProcessResult> powershell(String script, List<String> argumentos) {
  // Argumentos são encaminhados como dados; não interpolados no código PowerShell.
  return Process.run('powershell.exe', [
    '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
    '-Command', script, ...argumentos,
  ]);
}

Future<String> perguntaInicial(String nome, String quantidade) async {
  if (Platform.isLinux) {
    final resposta = await Process.run('zenity', [
      '--question', '--title=Hora do medicamento',
      '--text=$nome — $quantidade',
      '--ok-label=Confirmar alarme', '--cancel-label=Fechar',
      '--extra-button=Adiar 5 minutos',
    ]);
    if (resposta.stdout.toString().trim() == 'Adiar 5 minutos') return 'adiar';
    return resposta.exitCode == 0 ? 'confirmar' : 'fechar';
  }
  if (Platform.isWindows) {
    final resposta = await powershell(r'''Add-Type -AssemblyName System.Windows.Forms
$r=[System.Windows.Forms.MessageBox]::Show(
  "$($args[0]) - $($args[1])`nSIM: Confirmar alarme`nNÃO: Adiar 5 minutos`nCANCELAR: Fechar",
  'Hora do medicamento', 'YesNoCancel', 'Information')
Write-Output $r''', [nome, quantidade]);
    switch (resposta.stdout.toString().trim()) {
      case 'Yes': return 'confirmar';
      case 'No': return 'adiar';
      default: return 'fechar';
    }
  }
  return 'fechar';
}

Future<String> perguntarTomou(String nome) async {
  if (Platform.isLinux) {
    final resposta = await Process.run('zenity', [
      '--question', '--title=Confirmação da dose',
      '--text=Você tomou $nome?', '--ok-label=Sim',
      '--cancel-label=Sem resposta', '--extra-button=Não',
    ]);
    if (resposta.stdout.toString().trim() == 'Não') return 'nao';
    return resposta.exitCode == 0 ? 'sim' : 'sem_resposta';
  }
  if (Platform.isWindows) {
    final resposta = await powershell(r'''Add-Type -AssemblyName System.Windows.Forms
$r=[System.Windows.Forms.MessageBox]::Show(
  "Você tomou $($args[0])?`nSIM: Tomei`nNÃO: Não tomei`nCANCELAR: Sem resposta",
  'Confirmação da dose', 'YesNoCancel', 'Question')
Write-Output $r''', [nome]);
    switch (resposta.stdout.toString().trim()) {
      case 'Yes': return 'sim';
      case 'No': return 'nao';
      default: return 'sem_resposta';
    }
  }
  return 'sem_resposta';
}

Future<void> tocarSom() async {
  if (Platform.isLinux) {
    // Som do sistema, sem arquivos nem buffers mantidos em memória.
    await Process.run('canberra-gtk-play', ['-i', 'alarm-clock-elapsed']);
  } else if (Platform.isWindows) {
    await powershell(r'''Add-Type -AssemblyName System.Windows.Forms
[System.Media.SystemSounds]::Exclamation.Play()''', []);
  }
}

Future<void> executarInteracao(List<String> args) async {
  final caminho = args[1];
  final id = int.parse(args[2]);
  final data = DateTime.parse(args[3]);
  final horario = args[4];
  final nome = args[5];
  final quantidade = args[6];
  final chave = '${id}_${isoData(data)}_$horario';
  final banco = sqlite3.open(caminho);
  try {
    criarTabelas(banco);
    if (registrado(banco, chave)) return;
    await tocarSom();
    final escolha = await perguntaInicial(nome, quantidade);
    if (escolha == 'adiar') {
      banco.execute('''INSERT INTO adiamentos(chave_dose,novo_horario,atualizado_em)
        VALUES (?,?,?) ON CONFLICT(chave_dose) DO UPDATE SET
        novo_horario=excluded.novo_horario, atualizado_em=excluded.atualizado_em''',
        [chave, DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
         DateTime.now().toIso8601String()]);
      return;
    }
    if (escolha != 'confirmar' || registrado(banco, chave)) return;
    final resposta = await perguntarTomou(nome);
    if (resposta != 'sim' && resposta != 'nao') return;
    if (registrado(banco, chave)) return;
    banco.execute('''INSERT OR IGNORE INTO registros
      (chave,medicamento_id,data_programada,horario,situacao,registrado_em)
      VALUES (?,?,?,?,?,?)''',
      [chave, id, semHora(data).toIso8601String(), horario,
       resposta == 'sim' ? 'tomado' : 'nao_tomado', DateTime.now().toIso8601String()]);
    banco.execute('DELETE FROM adiamentos WHERE chave_dose = ?', [chave]);
  } finally {
    banco.dispose();
  }
}
