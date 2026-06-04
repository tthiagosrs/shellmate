import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants.dart';

class TranslateResult {
  final String? comando;
  final String? explicacao;
  final String? erro;
  final String? iaUsada;
  final dynamic raw;
  final bool fromCache;
  final int? historicoId;

  const TranslateResult({
    this.comando,
    this.explicacao,
    this.erro,
    this.iaUsada,
    this.raw,
    this.fromCache = false,
    this.historicoId,
  });
}

class RunResult {
  final String stdout;
  final String stderr;
  final int returnCode;

  const RunResult({
    required this.stdout,
    required this.stderr,
    required this.returnCode,
  });
}

class ChatService {
  Future<TranslateResult> translate({
    required String pedido,
    required String sistema,
    required String modo,
    required bool usarGroq,
  }) async {
    final res = await http.post(
      Uri.parse('$backendUrl/translate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pedido': pedido,
        'sistema': sistema,
        'modo': modo,
        'usar_groq': usarGroq,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Erro do servidor: ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return TranslateResult(
      comando: data['comando'] as String?,
      explicacao: data['explicacao'] as String?,
      erro: data['erro'] as String?,
      iaUsada: data['ia_usada'] as String?,
      raw: data['raw'],
      fromCache: data['from_cache'] as bool? ?? false,
      historicoId: data['historico_id'] as int?,
    );
  }

  Future<RunResult> runCommand(
    String command, {
    int? historicoId,
    String shell = 'bash',
  }) async {
    final res = await http.post(
      Uri.parse('$backendUrl/run'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'command': command,
        'shell': shell,
        'historico_id': historicoId,
      }),
    );

    if (res.statusCode != 200) {
      final detail = _extractDetail(res);
      throw Exception('HTTP ${res.statusCode}: $detail');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return RunResult(
      stdout: (data['stdout'] as String?)?.trim() ?? '',
      stderr: (data['stderr'] as String?)?.trim() ?? '',
      returnCode: data['returncode'] as int? ?? 0,
    );
  }

  String _extractDetail(http.Response res) {
    try {
      final payload = jsonDecode(res.body);
      if (payload is Map<String, dynamic> && payload.containsKey('detail')) {
        return payload['detail']?.toString() ?? res.body;
      }
    } catch (_) {}
    return res.body.isNotEmpty ? res.body : 'Erro desconhecido';
  }
}
