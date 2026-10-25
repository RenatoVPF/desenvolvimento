
import 'dart:io';

class Notificacoes {
  // Envia uma notificação nativa no Ubuntu.
  static Future<void> mostrar({
    required String titulo,
    required String mensagem,
  }) async {
    if (!Platform.isLinux) return;

    final resultado = await Process.run(
      'notify-send',
      [
        '-u',
        'critical',
        '-a',
        'Cronograma de Medicamentos',
        titulo,
        mensagem,
      ],
    );

    if (resultado.exitCode != 0) {
      stderr.writeln(
        'Falha ao exibir notificação: ${resultado.stderr}',
      );
    }
  }
}
