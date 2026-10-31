
import 'dart:async';
import 'package:flutter/material.dart';

import '../models/medicamento.dart';
import '../services/banco_dados.dart';
import '../services/cronograma.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int paginaSelecionada = 0;
  bool carregando = true;
  Timer? temporizadorAtualizacao;

  List<Medicamento> medicamentos = [];
  Map<String, String> situacoes = {};
  List<Map<String, Object?>> registros = [];

  final titulos = [
    'Hoje',
    'Medicamentos',
    'Calendário',
    'Histórico',
  ];

  final icones = [
    Icons.today,
    Icons.medication,
    Icons.calendar_month,
    Icons.history,
  ];

  @override
  void initState() {
    super.initState();
    atualizarDados();
    temporizadorAtualizacao = Timer.periodic(
      const Duration(seconds: 10), (_) => atualizarDados(),
    );
  }

  @override
  void dispose() {
    temporizadorAtualizacao?.cancel();
    super.dispose();
  }

  // Atualiza as informações exibidas nas telas.
  Future<void> atualizarDados() async {
    final novosMedicamentos =
        await BancoDados.instancia.listarMedicamentos();

    final novasSituacoes =
        await BancoDados.instancia.consultarSituacoes();

    final novosRegistros =
        await BancoDados.instancia.listarRegistros();

    if (!mounted) return;

    setState(() {
      medicamentos = novosMedicamentos;
      situacoes = novasSituacoes;
      registros = novosRegistros;
      carregando = false;
    });
  }

  // Abre o formulário de cadastro.
  Future<void> abrirCadastro() async {
    final medicamento = await showDialog<Medicamento>(
      context: context,
      builder: (context) => const FormularioMedicamento(),
    );

    if (medicamento == null) return;

    await BancoDados.instancia.adicionarMedicamento(medicamento);
    await atualizarDados();
  }

  // Registra uma dose como tomada ou não tomada.
  Future<void> alterarSituacao(Dose dose, String situacao) async {
    if (situacao == 'tomado') {
      final horarioProgramado = dose.horario.split(':');
      final instanteProgramado = DateTime(
        dose.data.year,
        dose.data.month,
        dose.data.day,
        int.parse(horarioProgramado[0]),
        int.parse(horarioProgramado[1]),
      );

      if (instanteProgramado.isAfter(DateTime.now())) {
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar registro'),
            content: const Text(
              'Esta dose está programada para o futuro. '
              'Deseja confirmar que já tomou?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        );

        if (confirmar != true) return;
      }
    }

    await BancoDados.instancia.registrarDose(dose, situacao);
    await atualizarDados();
  }

  Future<void> excluirMedicamento(Medicamento medicamento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir medicamento?'),
        content: Text(
          'Excluir ${medicamento.nome} também apagará seus registros. '
          'Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await BancoDados.instancia.excluirMedicamento(medicamento.id!);
    await atualizarDados();
  }

  String formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  // Constrói um cartão com os dados de uma dose.
  Widget construirCartaoDose(Dose dose) {
    final tomada = dose.situacao == 'tomado';
    final naoTomada = dose.situacao == 'nao_tomado';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              tomada
                  ? Icons.check_circle
                  : naoTomada
                      ? Icons.cancel
                      : Icons.schedule,
              color: tomada
                  ? Colors.green
                  : naoTomada
                      ? Colors.red
                      : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dose.medicamento.nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${dose.horario} • '
                    '${dose.medicamento.quantidade}',
                  ),
                  Text(
                    tomada
                        ? 'Tomado'
                        : naoTomada
                            ? 'Não tomado'
                            : 'Pendente',
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Registrar dose',
              onSelected: (valor) => alterarSituacao(dose, valor),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'tomado',
                  child: Text('Marcar como tomado'),
                ),
                PopupMenuItem(
                  value: 'nao_tomado',
                  child: Text('Marcar como não tomado'),
                ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }

  // Mostra os medicamentos programados para hoje.
  Widget construirHoje() {
    final doses = Cronograma.dosesDoDia(
      medicamentos,
      DateTime.now(),
      situacoes,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Medicamentos de hoje',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (doses.isEmpty)
          const Text('Nenhuma dose programada para hoje.'),
        for (final dose in doses) construirCartaoDose(dose),
      ],
    );
  }

  // Exibe os medicamentos cadastrados.
  Widget construirMedicamentos() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: abrirCadastro,
            icon: const Icon(Icons.add),
            label: const Text('Cadastrar medicamento'),
          ),
        ),
        const SizedBox(height: 16),
        if (medicamentos.isEmpty)
          const Text('Nenhum medicamento cadastrado.'),
        for (final medicamento in medicamentos)
          Card(
            child: ListTile(
              leading: const Icon(Icons.medication),
              title: Text(medicamento.nome),
              subtitle: Text(
                '${medicamento.quantidade}\n'
                'Horários: ${medicamento.horarios.join(', ')}\n'
                'A cada ${medicamento.intervaloDias} dia(s)\n'
                'Início: ${formatarData(medicamento.dataInicio)}\n'
                'Dose esquecida: '
                '${medicamento.regraEsquecimento == 'manter' ? 'Manter cronograma' : 'Revisar cronograma'}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Excluir medicamento',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => excluirMedicamento(medicamento),
              ),
            ),
          ),
      ],
    );
  }

  // Exibe as doses dos próximos sete dias.
  Widget construirCalendario() {
    final inicio = Cronograma.somenteData(DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Próximos 7 dias',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        for (var indice = 0; indice < 7; indice++)
          Builder(
            builder: (context) {
              final data = DateTime(
                inicio.year,
                inicio.month,
                inicio.day + indice,
              );

              final doses = Cronograma.dosesDoDia(
                medicamentos,
                data,
                situacoes,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      formatarData(data),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (doses.isEmpty)
                    const Text('Sem medicamentos programados.'),
                  for (final dose in doses)
                    construirCartaoDose(dose),
                  const Divider(),
                ],
              );
            },
          ),
      ],
    );
  }

  // Mostra os registros salvos no banco.
  Widget construirHistorico() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Histórico de doses',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (registros.isEmpty)
          const Text('Nenhum registro encontrado.'),
        for (final registro in registros)
          Card(
            child: ListTile(
              leading: Icon(
                registro['situacao'] == 'tomado'
                    ? Icons.check_circle
                    : Icons.cancel,
                color: registro['situacao'] == 'tomado'
                    ? Colors.green
                    : Colors.red,
              ),
              title: Text(registro['nome'] as String),
              subtitle: Text(
                '${formatarData(DateTime.parse(registro['data_programada'] as String))}'
                ' às ${registro['horario']}\n'
                '${registro['quantidade']} • '
                '${registro['situacao'] == 'tomado' ? 'Tomado' : 'Não tomado'}\n'
                'Registrado em: '
                '${formatarData(DateTime.parse(registro['registrado_em'] as String))}',
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }

  Widget construirPagina() {
    switch (paginaSelecionada) {
      case 0:
        return construirHoje();
      case 1:
        return construirMedicamentos();
      case 2:
        return construirCalendario();
      case 3:
        return construirHistorico();
      default:
        return construirHoje();
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinos = List.generate(
      titulos.length,
      (indice) => NavigationRailDestination(
        icon: Icon(icones[indice]),
        label: Text(titulos[indice]),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(titulos[paginaSelecionada]),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: paginaSelecionada,
                  onDestinationSelected: (indice) {
                    setState(() => paginaSelecionada = indice);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: destinos,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: construirPagina()),
              ],
            ),
    );
  }
}

// Formulário de cadastro de medicamentos.
class FormularioMedicamento extends StatefulWidget {
  const FormularioMedicamento({super.key});

  @override
  State<FormularioMedicamento> createState() =>
      _FormularioMedicamentoState();
}

class _FormularioMedicamentoState
    extends State<FormularioMedicamento> {
  final nomeController = TextEditingController();
  final quantidadeController = TextEditingController();

  DateTime dataInicio = DateTime.now();
  int intervaloDias = 1;
  String regraEsquecimento = 'manter';

  final List<String> horarios = [];

  @override
  void dispose() {
    nomeController.dispose();
    quantidadeController.dispose();
    super.dispose();
  }

  // Adiciona um horário escolhido pelo usuário.
  Future<void> adicionarHorario() async {
    final horario = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );

    if (horario == null) return;

    final texto =
        '${horario.hour.toString().padLeft(2, '0')}:'
        '${horario.minute.toString().padLeft(2, '0')}';

    setState(() {
      if (!horarios.contains(texto)) {
        horarios.add(texto);
        horarios.sort();
      }
    });
  }

  void salvar() {
    final nome = nomeController.text.trim();
    final quantidade = quantidadeController.text.trim();

    if (nome.isEmpty || quantidade.isEmpty || horarios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe o nome, a quantidade e pelo menos um horário.',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      Medicamento(
        nome: nome,
        quantidade: quantidade,
        horarios: List.from(horarios),
        dataInicio: Cronograma.somenteData(dataInicio),
        intervaloDias: intervaloDias,
        regraEsquecimento: regraEsquecimento,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cadastrar medicamento'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do medicamento',
                ),
              ),
              TextField(
                controller: quantidadeController,
                decoration: const InputDecoration(
                  labelText: 'Quantidade por dose',
                  hintText: 'Ex.: 1 comprimido',
                ),
              ),
              const SizedBox(height: 16),
              const Text('Horários'),
              Wrap(
                spacing: 8,
                children: [
                  for (final horario in horarios)
                    InputChip(
                      label: Text(horario),
                      onDeleted: () {
                        setState(() => horarios.remove(horario));
                      },
                    ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: adicionarHorario,
                icon: const Icon(Icons.add_alarm),
                label: const Text('Adicionar horário'),
              ),
              const SizedBox(height: 12),
              const Text('Frequência'),
              DropdownButtonFormField<int>(
                initialValue: intervaloDias,
                items: const [
                  DropdownMenuItem(
                    value: 1,
                    child: Text('Todos os dias'),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('Dia sim, dia não'),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('A cada 3 dias'),
                  ),
                  DropdownMenuItem(
                    value: 4,
                    child: Text('A cada 4 dias'),
                  ),
                  DropdownMenuItem(
                    value: 7,
                    child: Text('A cada 7 dias'),
                  ),
                ],
                onChanged: (valor) {
                  setState(() => intervaloDias = valor ?? 1);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(
                  'Data inicial: '
                  '${dataInicio.day}/${dataInicio.month}/${dataInicio.year}',
                ),
                onPressed: () async {
                  final data = await showDatePicker(
                    context: context,
                    initialDate: dataInicio,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );

                  if (data != null) {
                    setState(() => dataInicio = data);
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text('Se esquecer uma dose'),
              DropdownButtonFormField<String>(
                initialValue: regraEsquecimento,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'manter',
                    child: Text('Manter cronograma'),
                  ),
                  DropdownMenuItem(
                    value: 'revisar',
                    child: Text('Solicitar revisão'),
                  ),
                ],
                onChanged: (valor) {
                  setState(() {
                    regraEsquecimento = valor ?? 'manter';
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Nesta versão, uma dose esquecida não altera '
                'automaticamente as próximas datas.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: salvar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
