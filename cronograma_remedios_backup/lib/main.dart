
import 'package:flutter/material.dart';

import 'screens/tela_principal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CronogramaRemedios());
}

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
