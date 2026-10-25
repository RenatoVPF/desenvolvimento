
import 'package:flutter/material.dart';

void main() {
  runApp(const CronogramaRemedios());
}

// Configuração principal do aplicativo.
class CronogramaRemedios extends StatelessWidget {
  const CronogramaRemedios({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cronograma de Medicamentos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ),
        useMaterial3: true,
      ),
      home: const TelaPrincipal(),
    );
  }
}

// Tela principal responsável pela navegação.
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int paginaSelecionada = 0;

  final List<String> titulosPaginas = [
    'Hoje',
    'Medicamentos',
    'Calendário',
    'Histórico',
  ];

  final List<IconData> iconesPaginas = [
    Icons.today,
    Icons.medication,
    Icons.calendar_month,
    Icons.history,
  ];

  // Atualiza a página selecionada.
  void selecionarPagina(int indice) {
    setState(() {
      paginaSelecionada = indice;
    });
  }

  // Exibe o conteúdo correspondente à página.
  Widget construirConteudo() {
    switch (paginaSelecionada) {
      case 0:
        return const TelaHoje();
      case 1:
        return const TelaMedicamentos();
      case 2:
        return const TelaCalendario();
      case 3:
        return const TelaHistorico();
      default:
        return const TelaHoje();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulosPaginas[paginaSelecionada]),
        backgroundColor:
            Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: paginaSelecionada,
            onDestinationSelected: selecionarPagina,
            labelType: NavigationRailLabelType.all,
            destinations: List.generate(
              titulosPaginas.length,
              (indice) => NavigationRailDestination(
                icon: Icon(iconesPaginas[indice]),
                label: Text(titulosPaginas[indice]),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: construirConteudo(),
          ),
        ],
      ),
    );
  }
}

// Apresenta as doses programadas para o dia.
class TelaHoje extends StatelessWidget {
  const TelaHoje({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.today, size: 64),
          SizedBox(height: 16),
          Text(
            'Medicamentos de hoje',
            style: TextStyle(fontSize: 24),
          ),
          SizedBox(height: 8),
          Text('Nenhuma dose cadastrada.'),
        ],
      ),
    );
  }
}

// Área de gerenciamento dos medicamentos.
class TelaMedicamentos extends StatelessWidget {
  const TelaMedicamentos({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'O cadastro será implementado em breve.',
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Cadastrar medicamento'),
      ),
    );
  }
}

// Área destinada ao calendário de doses.
class TelaCalendario extends StatelessWidget {
  const TelaCalendario({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Calendário de medicamentos',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}

// Área destinada aos registros de administração.
class TelaHistorico extends StatelessWidget {
  const TelaHistorico({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Histórico de medicamentos',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}
