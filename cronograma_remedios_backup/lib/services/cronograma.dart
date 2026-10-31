
import '../models/medicamento.dart';

class Cronograma {
  // Remove as horas para comparar apenas as datas.
  static DateTime somenteData(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  // Calcula a diferença de dias usando datas de calendário.
  static int diferencaDias(DateTime inicio, DateTime fim) {
    final primeira = DateTime.utc(
      inicio.year, inicio.month, inicio.day,
    );

    final segunda = DateTime.utc(
      fim.year, fim.month, fim.day,
    );

    return segunda.difference(primeira).inDays;
  }

  // Verifica se o medicamento está programado para uma data.
  static bool deveTomar(
    Medicamento medicamento,
    DateTime data,
  ) {
    final diferenca = diferencaDias(
      medicamento.dataInicio,
      data,
    );

    if (diferenca < 0) return false;

    return diferenca % medicamento.intervaloDias == 0;
  }

  // Gera todas as doses programadas em determinado dia.
  static List<Dose> dosesDoDia(
    List<Medicamento> medicamentos,
    DateTime data,
    Map<String, String> situacoes,
  ) {
    final doses = <Dose>[];

    for (final medicamento in medicamentos) {
      if (!deveTomar(medicamento, data)) continue;

      for (final horario in medicamento.horarios) {
        final dose = Dose(
          medicamento: medicamento,
          data: somenteData(data),
          horario: horario,
        );

        doses.add(
          Dose(
            medicamento: medicamento,
            data: dose.data,
            horario: horario,
            situacao: situacoes[dose.chave],
          ),
        );
      }
    }

    doses.sort((primeira, segunda) {
      return primeira.horario.compareTo(segunda.horario);
    });

    return doses;
  }

  // Gera doses para um período de vários dias.
  static List<Dose> dosesDoPeriodo(
    List<Medicamento> medicamentos,
    DateTime inicio,
    int quantidadeDias,
    Map<String, String> situacoes,
  ) {
    final doses = <Dose>[];

    for (var dia = 0; dia < quantidadeDias; dia++) {
      final data = DateTime(
        inicio.year,
        inicio.month,
        inicio.day + dia,
      );

      doses.addAll(
        dosesDoDia(medicamentos, data, situacoes),
      );
    }

    return doses;
  }
}
