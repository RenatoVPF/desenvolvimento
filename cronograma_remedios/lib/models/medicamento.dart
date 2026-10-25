
class Medicamento {
  final int? id;
  final String nome;
  final String quantidade;
  final List<String> horarios;
  final DateTime dataInicio;
  final int intervaloDias;
  final String regraEsquecimento;

  const Medicamento({
    this.id,
    required this.nome,
    required this.quantidade,
    required this.horarios,
    required this.dataInicio,
    required this.intervaloDias,
    required this.regraEsquecimento,
  });

  Map<String, Object?> paraMapa() {
    return {
      'nome': nome,
      'quantidade': quantidade,
      'horarios': horarios.join(','),
      'data_inicio': dataInicio.toIso8601String(),
      'intervalo_dias': intervaloDias,
      'regra_esquecimento': regraEsquecimento,
    };
  }

  factory Medicamento.doMapa(Map<String, Object?> mapa) {
    return Medicamento(
      id: mapa['id'] as int,
      nome: mapa['nome'] as String,
      quantidade: mapa['quantidade'] as String,
      horarios: (mapa['horarios'] as String).split(','),
      dataInicio: DateTime.parse(mapa['data_inicio'] as String),
      intervaloDias: mapa['intervalo_dias'] as int,
      regraEsquecimento: mapa['regra_esquecimento'] as String,
    );
  }
}

class Dose {
  final Medicamento medicamento;
  final DateTime data;
  final String horario;
  final String? situacao;

  const Dose({
    required this.medicamento,
    required this.data,
    required this.horario,
    this.situacao,
  });

  String get chave =>
      '${medicamento.id}_${data.year}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}_$horario';
}

