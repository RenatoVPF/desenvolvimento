
import 'dart:io';

import 'package:path/path.dart' as caminho;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/medicamento.dart';

class BancoDados {
  BancoDados._();

  static final BancoDados instancia = BancoDados._();

  Database? _banco;

  Future<Database> get banco async {
    if (_banco != null) return _banco!;

    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final diretorio = await getApplicationSupportDirectory();
    final arquivo = caminho.join(
      diretorio.path,
      'cronograma_remedios.db',
    );

    _banco = await openDatabase(
      arquivo,
      version: 1,
      onCreate: (db, versao) async {
        await db.execute('''
          CREATE TABLE medicamentos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nome TEXT NOT NULL,
            quantidade TEXT NOT NULL,
            horarios TEXT NOT NULL,
            data_inicio TEXT NOT NULL,
            intervalo_dias INTEGER NOT NULL,
            regra_esquecimento TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE registros (
            chave TEXT PRIMARY KEY,
            medicamento_id INTEGER NOT NULL,
            data_programada TEXT NOT NULL,
            horario TEXT NOT NULL,
            situacao TEXT NOT NULL,
            registrado_em TEXT NOT NULL
          )
        ''');
      },
    );

    return _banco!;
  }

  Future<void> adicionarMedicamento(Medicamento medicamento) async {
    final db = await banco;
    await db.insert('medicamentos', medicamento.paraMapa());
  }

  Future<List<Medicamento>> listarMedicamentos() async {
    final db = await banco;
    final resultado = await db.query(
      'medicamentos',
      orderBy: 'nome ASC',
    );

    return resultado.map(Medicamento.doMapa).toList();
  }

  Future<void> excluirMedicamento(int id) async {
    final db = await banco;

    await db.transaction((transacao) async {
      await transacao.delete(
        'registros',
        where: 'medicamento_id = ?',
        whereArgs: [id],
      );

      await transacao.delete(
        'medicamentos',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> registrarDose(
    Dose dose,
    String situacao,
  ) async {
    final db = await banco;

    await db.insert(
      'registros',
      {
        'chave': dose.chave,
        'medicamento_id': dose.medicamento.id,
        'data_programada': dose.data.toIso8601String(),
        'horario': dose.horario,
        'situacao': situacao,
        'registrado_em': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> consultarSituacoes() async {
    final db = await banco;
    final registros = await db.query('registros');

    return {
      for (final registro in registros)
        registro['chave'] as String:
            registro['situacao'] as String,
    };
  }

  Future<List<Map<String, Object?>>> listarRegistros() async {
    final db = await banco;

    return db.rawQuery('''
      SELECT
        r.data_programada,
        r.horario,
        r.situacao,
        r.registrado_em,
        m.nome,
        m.quantidade
      FROM registros r
      INNER JOIN medicamentos m
        ON m.id = r.medicamento_id
      ORDER BY r.data_programada DESC, r.horario DESC
    ''');
  }
}
