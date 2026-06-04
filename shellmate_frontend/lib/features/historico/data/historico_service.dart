import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants.dart';

class HistoricoItem {
  final int id;
  final String inputUsuario;
  final String comandoGerado;
  final String sistemaOperacional;
  final bool executado;
  final String? resultado;
  final String dataHora;

  const HistoricoItem({
    required this.id,
    required this.inputUsuario,
    required this.comandoGerado,
    required this.sistemaOperacional,
    required this.executado,
    this.resultado,
    required this.dataHora,
  });

  factory HistoricoItem.fromJson(Map<String, dynamic> json) => HistoricoItem(
        id: json['id'] as int,
        inputUsuario: json['input_usuario'] as String,
        comandoGerado: json['comando_gerado'] as String,
        sistemaOperacional: json['sistema_operacional'] as String,
        executado: json['executado'] as bool,
        resultado: json['resultado'] as String?,
        dataHora: json['data_hora'] as String,
      );
}

class HistoricoService {
  Future<List<HistoricoItem>> listar({int limite = 20}) async {
    final res = await http
        .get(Uri.parse('$backendUrl/historico?limite=$limite'))
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Erro ao carregar histórico: ${res.statusCode}');
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => HistoricoItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<HistoricoItem>> buscar(String termo) async {
    final uri = Uri.parse('$backendUrl/buscar')
        .replace(queryParameters: {'termo': termo});
    final res = await http.get(uri).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Erro na busca: ${res.statusCode}');
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => HistoricoItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> excluir(int id) async {
    final res = await http
        .delete(Uri.parse('$backendUrl/historico/$id'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Erro ao excluir: ${res.statusCode}');
    }
  }

  Future<void> limparTudo() async {
    final res = await http
        .delete(Uri.parse('$backendUrl/historico'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Erro ao limpar: ${res.statusCode}');
    }
  }
}
