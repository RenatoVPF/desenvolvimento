
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cronograma_remedios/main.dart';

void main() {
  testWidgets(
    'O aplicativo possui a configuração principal',
    (WidgetTester tester) async {
      const aplicativo = CronogramaRemedios();

      expect(aplicativo, isA<StatelessWidget>());
    },
  );
}
