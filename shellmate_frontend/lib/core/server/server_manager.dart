import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants.dart';

Process? _process;

Future<bool> isServerRunning() async {
  try {
    final res = await http
        .get(Uri.parse('$backendUrl/health'))
        .timeout(const Duration(seconds: 1));
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<void> startServer() async {
  if (await isServerRunning()) return;

  _process = await Process.start(
    pythonExe,
    [
      '-m', 'uvicorn', 'server:app',
      '--host', '127.0.0.1',
      '--port', '5000',
      '--loop', 'asyncio',
      '--http', 'h11',
    ],
    workingDirectory: projectDir,
  );

  // ignore: avoid_print
  _process!.stdout.transform(utf8.decoder).listen((d) => print('[server] $d'));
  // ignore: avoid_print
  _process!.stderr.transform(utf8.decoder).listen((d) => print('[server] $d'));
}

Future<void> waitForServer({int maxAttempts = 30}) async {
  for (int i = 0; i < maxAttempts; i++) {
    await Future.delayed(const Duration(milliseconds: 500));
    if (await isServerRunning()) return;
  }
  throw Exception(
    'Servidor não respondeu após ${(maxAttempts * 0.5).toStringAsFixed(0)}s.',
  );
}

void stopServer() {
  _process?.kill();
  _process = null;
}
