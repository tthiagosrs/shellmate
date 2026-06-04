import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/platform/platform_info.dart';
import '../../../core/theme/app_colors.dart';
import '../data/chat_service.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/side_bar.dart';
import 'widgets/terminal_panel.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _sideBarKey = GlobalKey<SideBarState>();
  final _service = ChatService();
  final _terminalController = TerminalController();

  final List<ChatMessage> _messages = [];

  bool _sending = false;
  bool _runCommand = false;
  bool _isStreamingResponse = false;
  bool _showTerminal = false;
  double _terminalWidth = 420;
  String _selectedModel = 'Gemini';
  String _selectedMode = 'tecnico';
  late String _greeting;

  // t=0 → welcome, t=1 → chat
  late AnimationController _transCtrl;
  late Animation<double> _transAnim;

  static const _greetings = [
    'Como posso te ajudar?',
    'O que vamos fazer hoje?',
    'Qual comando você precisa?',
    'Pronto para o terminal.',
    'Por onde começamos?',
    'Me diga o que precisa.',
  ];

  @override
  void initState() {
    super.initState();
    _greeting = _greetings[Random().nextInt(_greetings.length)];
    _transCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _transAnim = CurvedAnimation(parent: _transCtrl, curve: Curves.easeInOut);
  }

  // ── Executar no terminal ──────────────────────────────────────────────────

  void _runInTerminal(String cmd) {
    if (!_showTerminal) {
      setState(() => _showTerminal = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _terminalController.runCommand(cmd);
      });
    } else {
      _terminalController.runCommand(cmd);
    }
  }

  // ── Novo chat ─────────────────────────────────────────────────────────────

  void _newChat() {
    _isStreamingResponse = false;
    _transCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _sending = false;
        _controller.clear();
        final current = _greeting;
        String next;
        do {
          next = _greetings[Random().nextInt(_greetings.length)];
        } while (next == current && _greetings.length > 1);
        _greeting = next;
      });
    });
  }

  // ── Scroll ────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Envio de mensagem ─────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final isFirst = _messages.isEmpty;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messages.add(ChatMessage(text: '', isUser: false, isStreaming: true));
      _sending = true;
      _controller.clear();
    });

    final aiMsgIndex = _messages.length - 1;
    if (isFirst) _transCtrl.forward();
    _scrollToBottom();

    try {
      final result = await _service.translate(
        pedido: text,
        sistema: PlatformInfo.sistema,
        modo: _selectedMode,
        usarGroq: _selectedModel == 'Groq',
      );

      if (!mounted) return;

      final iaLabel =
          result.fromCache ? 'cache' : result.iaUsada ?? 'desconhecida';

      final botText = result.erro != null
          ? 'Erro: ${result.erro}'
          : result.comando != null
              ? 'Sugestão de comando:\n${result.comando}\n\nIA usada: $iaLabel'
                  '${result.fromCache ? ' (resposta em cache)' : ''}'
              : result.explicacao ?? 'Sem resposta do backend.';

      await _streamText(botText, aiMsgIndex, fromCache: result.fromCache);

      if (!mounted) return;
      if (aiMsgIndex >= _messages.length) return;

      setState(() => _sending = false);
      _scrollToBottom();
      _sideBarKey.currentState?.refresh();

      if (result.raw != null && !result.fromCache) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Resposta bruta da IA:\n${_formatRaw(result.raw)}',
            isUser: false,
          ));
        });
      }

      if (result.comando != null && _runCommand) {
        await _executeCommand(result.comando!,
            historicoId: result.historicoId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (aiMsgIndex < _messages.length) {
          _messages[aiMsgIndex] = ChatMessage(
            text: 'Não foi possível conectar ao backend: $e',
            isUser: false,
          );
        }
        _sending = false;
      });
      _isStreamingResponse = false;
      _scrollToBottom();
    }
  }

  // ── Streaming de texto ────────────────────────────────────────────────────

  Future<void> _streamText(
    String fullText,
    int index, {
    bool fromCache = false,
  }) async {
    _isStreamingResponse = true;
    final charDelay = fullText.length > 300
        ? const Duration(milliseconds: 5)
        : fullText.length > 100
            ? const Duration(milliseconds: 9)
            : const Duration(milliseconds: 14);

    for (int i = 1; i <= fullText.length; i++) {
      await Future.delayed(charDelay);
      if (!mounted || !_isStreamingResponse) return;
      if (index >= _messages.length) return;
      setState(() {
        _messages[index] = ChatMessage(
          text: fullText.substring(0, i),
          isUser: false,
          fromCache: fromCache,
          isStreaming: i < fullText.length,
        );
      });
      if (i % 30 == 0) _scrollToBottom();
    }
    _isStreamingResponse = false;
  }

  // ── Execução de comando ───────────────────────────────────────────────────

  Future<void> _executeCommand(String command, {int? historicoId}) async {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
          text: 'Executando no ${PlatformInfo.displayName}:\n$command',
          isUser: false));
    });
    _scrollToBottom();

    try {
      final result = await _service.runCommand(
        command,
        historicoId: historicoId,
        shell: PlatformInfo.shell,
      );
      if (!mounted) return;

      final output = StringBuffer()
        ..writeln('Resultado da execução:')
        ..writeln('Código de saída: ${result.returnCode}')
        ..writeln('')
        ..writeln(result.stdout.isEmpty
            ? 'Saída: (vazia)'
            : 'Saída:\n${result.stdout}');

      if (result.stderr.isNotEmpty) {
        output
          ..writeln('')
          ..writeln('Erros:\n${result.stderr}');
      }

      setState(() {
        _messages.add(ChatMessage(text: output.toString(), isUser: false));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
            ChatMessage(text: 'Erro ao executar comando: $e', isUser: false));
      });
      _scrollToBottom();
    }
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
    _scrollController.dispose();
    _transCtrl.dispose();
    super.dispose();
  }

  Widget _buildInputBar() {
    return ChatInputBar(
      controller: _controller,
      sending: _sending,
      onSend: _sendMessage,
      selectedModel: _selectedModel,
      selectedMode: _selectedMode,
      runCommand: _runCommand,
      onModelChanged: (v) => setState(() => _selectedModel = v),
      onModeChanged: (v) => setState(() => _selectedMode = v),
      onRunCommandChanged: (v) => setState(() => _runCommand = v),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      body: Row(
        children: [
          // ── Sidebar ──
          SideBar(
            key: _sideBarKey,
            onNewChat: _newChat,
            onSelectCommand: (cmd) {
              _controller.text = cmd;
            },
          ),

          // ── Área principal ──
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  terminalVisible: _showTerminal,
                  onToggleTerminal: () =>
                      setState(() => _showTerminal = !_showTerminal),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildAnimatedBody()),
                      if (_showTerminal) ...[
                        _PanelDivider(
                          onDrag: (dx) => setState(() {
                            _terminalWidth =
                                (_terminalWidth - dx).clamp(200.0, 800.0);
                          }),
                        ),
                        SizedBox(
                          width: _terminalWidth,
                          child: TerminalPanel(
                              controller: _terminalController),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _transAnim,
          builder: (context, _) {
            final t = _transAnim.value;
            final heroAlpha = (1.0 - t * 2.2).clamp(0.0, 1.0);
            final chatAlpha = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
            final spacer = h * 0.38 * (1.0 - t);

            return Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Lista de mensagens
                      Opacity(
                        opacity: chatAlpha,
                        child: Transform.translate(
                          offset: Offset(0, 24.0 * (1.0 - t)),
                          child: ListView.separated(
                            controller: _scrollController,
                            padding:
                                const EdgeInsets.fromLTRB(16, 20, 16, 8),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) => _AnimatedEntry(
                              key: ValueKey(i),
                              child: MessageBubble(
                                message: _messages[i],
                                onRunInTerminal: _runInTerminal,
                              ),
                            ),
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 20),
                          ),
                        ),
                      ),
                      // Hero de boas-vindas
                      IgnorePointer(
                        ignoring: heroAlpha < 0.01,
                        child: Opacity(
                          opacity: heroAlpha,
                          child: Transform.translate(
                            offset: Offset(0, -32.0 * t),
                            child: Center(
                              child: _WelcomeHero(greeting: _greeting),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Input bar
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _buildInputBar(),
                  ),
                ),
                SizedBox(height: spacer + t * 14),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Barra superior minimal ────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool terminalVisible;
  final VoidCallback onToggleTerminal;

  const _TopBar({
    required this.terminalVisible,
    required this.onToggleTerminal,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Spacer(),
          _TerminalToggleButton(
            active: terminalVisible,
            onTap: onToggleTerminal,
          ),
          const SizedBox(width: 8),
          const _OsBadge(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Botão de toggle do terminal ───────────────────────────────────────────────

class _TerminalToggleButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _TerminalToggleButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active ? c.accentSub : c.accentDim,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? c.accentStrong : c.accentBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal_rounded, size: 12, color: c.accent),
            const SizedBox(width: 5),
            Text(
              'Terminal',
              style: TextStyle(
                color: c.accent,
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Divisor arrastável entre os painéis ───────────────────────────────────────

class _PanelDivider extends StatefulWidget {
  final Function(double) onDrag;
  const _PanelDivider({required this.onDrag});

  @override
  State<_PanelDivider> createState() => _PanelDividerState();
}

class _PanelDividerState extends State<_PanelDivider> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 5,
          color: _hover
              ? c.accent.withValues(alpha: 0.5)
              : c.divider,
        ),
      ),
    );
  }
}

// ── Entrada animada de mensagem ───────────────────────────────────────────────

class _AnimatedEntry extends StatefulWidget {
  final Widget child;
  const _AnimatedEntry({super.key, required this.child});

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Hero de boas-vindas ───────────────────────────────────────────────────────

class _WelcomeHero extends StatelessWidget {
  final String greeting;
  const _WelcomeHero({required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1A3A5C), Color(0xFF0A1828)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFF5BCEFA).withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5BCEFA).withValues(alpha: 0.13),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: const Color(0xFF5BCEFA).withValues(alpha: 0.06),
                  blurRadius: 80,
                  spreadRadius: 24,
                ),
              ],
            ),
            child: const Icon(
              Icons.terminal_rounded,
              size: 36,
              color: Color(0xFF5BCEFA),
            ),
          ),
          const SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF5BCEFA), Color(0xFF8BB0FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              greeting,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Descreva o que você quer fazer no terminal',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.of(context).text3,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge do SO na top bar ────────────────────────────────────────────────────

class _OsBadge extends StatelessWidget {
  const _OsBadge();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: PlatformInfo.version,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: c.accentDim,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.accentBorder, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_osIcon(), size: 12, color: c.accent),
            const SizedBox(width: 5),
            Text(
              PlatformInfo.displayName,
              style: TextStyle(
                color: c.accent,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _osIcon() {
    switch (PlatformInfo.sistema) {
      case 'Windows':
        return Icons.window_rounded;
      case 'Darwin':
        return Icons.laptop_mac_rounded;
      default:
        return Icons.terminal_rounded;
    }
  }
}
