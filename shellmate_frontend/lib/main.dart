import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String backendUrl = 'http://127.0.0.1:5000';

void main() {
  runApp(const ShellmateApp());
}

class ShellmateApp extends StatelessWidget {
  const ShellmateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shellmate Chat',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E0F13),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF15171D),
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFE8EAF0), fontSize: 14),
          bodyMedium: TextStyle(color: Color(0xFF8B8FA8), fontSize: 13),
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: 'Olá! Eu sou o Shellmate. Pergunte algo e eu responderei com um comando ou explicação.',
      isUser: false,
    ),
  ];
  bool _sending = false;
  bool _runCommand = false;
  String _selectedModel = 'Gemini';
  String _selectedMode = 'tecnico';

  static const Map<String, String> _modelOptions = {
    'Gemini': 'Gemini',
    'Groq': 'Groq',
  };

  static const Map<String, String> _modeOptions = {
    'tecnico': 'Técnico',
    'resumido': 'Resumido',
    'professor': 'Professor',
    'detalhado': 'Detalhado',
    'suporte': 'Suporte',
  };

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _sending = true;
      _controller.clear();
    });

    try {
      final uri = Uri.parse('$backendUrl/translate');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pedido': text,
          'sistema': 'Windows',
          'modo': _selectedMode,
          'usar_groq': _selectedModel == 'Groq',
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final comando = data['comando'] as String?;
        final explicacao = data['explicacao'] as String?;
        final erro = data['erro'] as String?;
        final iaUsada = data['ia_usada'] as String?;
        final raw = data['raw'];

        final botText = erro != null
            ? 'Erro: $erro'
            : comando != null
                ? 'Sugestão de comando:\n$comando\n\nIA usada: ${iaUsada ?? 'desconhecida'}'
                : explicacao ?? 'Sem resposta do backend.';

        setState(() {
          _messages.add(_ChatMessage(text: botText, isUser: false));
          if (raw != null) {
            _messages.add(_ChatMessage(text: 'Resposta bruta da IA:\n${_formatRaw(raw)}', isUser: false));
          }
          _sending = false;
        });

        if (comando != null && _runCommand) {
          await _executeCommand(comando);
        }
      } else {
        setState(() {
          _messages.add(_ChatMessage(
            text: 'Erro do servidor: ${response.statusCode}',
            isUser: false,
          ));
          _sending = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: 'Não foi possível conectar ao backend: $e', isUser: false));
        _sending = false;
      });
    }
  }

  Future<void> _executeCommand(String command) async {
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(text: 'Executando no Windows:\n$command', isUser: false));
    });

    try {
      final uri = Uri.parse('$backendUrl/run');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'command': command,
          'shell': 'powershell',
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final stdout = (data['stdout'] as String?)?.trim() ?? '';
        final stderr = (data['stderr'] as String?)?.trim() ?? '';
        final returnCode = data['returncode'] as int? ?? 0;

        final executionText = StringBuffer()
          ..writeln('Resultado da execução:')
          ..writeln('Código de saída: $returnCode')
          ..writeln('')
          ..writeln(stdout.isEmpty ? 'Saída: (vazia)' : 'Saída:\n$stdout');

        if (stderr.isNotEmpty) {
          executionText.writeln('');
          executionText.writeln('Erros:\n$stderr');
        }

        setState(() {
          _messages.add(_ChatMessage(text: executionText.toString(), isUser: false));
        });
      } else {
        final detail = _extractErrorDetail(response);
        setState(() {
          _messages.add(_ChatMessage(
            text: 'Falha ao executar comando (HTTP ${response.statusCode}):\n$detail',
            isUser: false,
          ));
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: 'Erro ao executar comando: $e', isUser: false));
      });
    }
  }

  String _extractErrorDetail(http.Response response) {
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        if (payload.containsKey('detail')) {
          return payload['detail']?.toString() ?? response.body;
        }
      }
    } catch (_) {
      // ignore invalid JSON
    }
    return response.body.isNotEmpty ? response.body : 'Erro desconhecido';
  }

  String _formatRaw(dynamic raw) {
    try {
      return const JsonEncoder.withIndent('  ').convert(raw);
    } catch (_) {
      return raw.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shellmate'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF15171D),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedModel,
                        decoration: const InputDecoration(
                          labelText: 'Modelo',
                          labelStyle: TextStyle(color: Color(0xFF8B8FA8)),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF2A2D36)),
                          ),
                        ),
                        dropdownColor: const Color(0xFF15171D),
                        style: const TextStyle(color: Color(0xFFE8EAF0)),
                        items: _modelOptions.entries
                            .map((entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedModel = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedMode,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de resposta',
                          labelStyle: TextStyle(color: Color(0xFF8B8FA8)),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF2A2D36)),
                          ),
                        ),
                        dropdownColor: const Color(0xFF15171D),
                        style: const TextStyle(color: Color(0xFFE8EAF0)),
                        items: _modeOptions.entries
                            .map((entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedMode = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Executar comando no Windows',
                        style: TextStyle(color: Color(0xFFE8EAF0), fontSize: 13),
                      ),
                    ),
                    Switch(
                      value: _runCommand,
                      activeThumbColor: const Color(0xFF5BCEFA),
                      onChanged: (value) {
                        setState(() {
                          _runCommand = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A2D36)),
          Expanded(
            child: ListView.separated(
              reverse: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _MessageBubble(message: message);
              },
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemCount: _messages.length,
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF15171D),
              border: Border(top: BorderSide(color: Color(0xFF2A2D36), width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Color(0xFFE8EAF0), fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Pergunte ao Shellmate...',
                      hintStyle: TextStyle(color: Color(0xFF8B8FA8)),
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _sendMessage,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _sending ? const Color(0xFF5BCEFA).withValues(alpha: 128) : const Color(0xFF5BCEFA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _sending ? Icons.autorenew : Icons.send,
                      size: 20,
                      color: const Color(0xFF0A1A22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final bgColor = message.isUser ? const Color(0xFFF5A9B8).withValues(alpha: 46) : const Color(0xFF1C1E26);
    final borderColor = message.isUser ? const Color(0xFFF5A9B8).withValues(alpha: 97) : const Color(0xFF2A2D36);
    final textColor = message.isUser ? const Color.fromARGB(255, 82, 57, 62) : const Color(0xFFE8EAF0);

    return Row(
      mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(color: textColor, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 6),
                Text(
                  'Agora',
                  style: const TextStyle(color: Color(0xFF8B8FA8), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
