import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool fromCache;
  final bool isStreaming;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.fromCache = false,
    this.isStreaming = false,
  });
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(String)? onRunInTerminal;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRunInTerminal,
  });

  @override
  Widget build(BuildContext context) {
    return message.isUser
        ? _UserBubble(message: message)
        : _AiBubble(message: message, onRunInTerminal: onRunInTerminal);
  }
}

// ── Mensagem do usuário ──────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(width: 60),
        Flexible(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2535), Color(0xFF1A2030)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              border: Border.all(
                color: c.accent.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                color: Color(0xFFE8EAF0),
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Mensagem da IA ───────────────────────────────────────────────────────────

class _AiBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(String)? onRunInTerminal;
  const _AiBubble({required this.message, this.onRunInTerminal});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(right: 10, top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1A3A4A), Color(0xFF0E2030)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: c.accent.withValues(alpha: 0.31),
              width: 0.5,
            ),
          ),
          child: Icon(
            Icons.terminal_rounded,
            size: 15,
            color: c.accent,
          ),
        ),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.fromCache)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.accentDim,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: c.accent.withValues(alpha: 0.31),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded,
                            size: 11, color: c.accent),
                        const SizedBox(width: 3),
                        Text(
                          'Cache',
                          style: TextStyle(
                            color: c.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _buildContent(context),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.isStreaming) {
      if (message.text.isEmpty) return const _TypingDots();
      return _PlainBubble(text: message.text, isStreaming: true);
    }
    if (message.text.contains('Sugestão de comando:')) {
      return _CommandBubble(text: message.text, onRunInTerminal: onRunInTerminal);
    }
    if (message.text.startsWith('Resposta bruta da IA:')) {
      return _RawBubble(text: message.text);
    }
    return _PlainBubble(text: message.text);
  }
}

// ── Bubble simples ───────────────────────────────────────────────────────────

class _PlainBubble extends StatelessWidget {
  final String text;
  final bool isStreaming;
  const _PlainBubble({required this.text, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = TextStyle(color: c.text1, fontSize: 14, height: 1.6);
    if (isStreaming) {
      return Text.rich(
        TextSpan(
          text: text,
          style: style,
          children: const [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _BlinkingCursor(),
            ),
          ],
        ),
      );
    }
    return Text(text, style: style);
  }
}

// ── Cursor piscando ───────────────────────────────────────────────────────────

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return FadeTransition(
      opacity: _ctrl,
      child: Text(
        '▋',
        style: TextStyle(color: c.accent, fontSize: 14, height: 1.0),
      ),
    );
  }
}

// ── Pontos de digitação ───────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value + i * 0.33) % 1.0;
            final y = -sin(phase * 2 * pi).clamp(0.0, 1.0) * 6.0;
            return Transform.translate(
              offset: Offset(0, y),
              child: Padding(
                padding: EdgeInsets.only(right: i < 2 ? 5.0 : 0.0),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.accent.withValues(alpha: 0.65),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Bubble com comando destacado ─────────────────────────────────────────────

class _CommandBubble extends StatelessWidget {
  final String text;
  final void Function(String)? onRunInTerminal;
  const _CommandBubble({required this.text, this.onRunInTerminal});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final lines = text.split('\n');
    String? command;
    final otherLines = <String>[];

    bool nextIsCommand = false;
    for (final line in lines) {
      if (line.trim() == 'Sugestão de comando:') {
        nextIsCommand = true;
        continue;
      }
      if (nextIsCommand && line.trim().isNotEmpty) {
        command = line.trim();
        nextIsCommand = false;
        continue;
      }
      if (line.trim().isNotEmpty) otherLines.add(line);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (otherLines.isNotEmpty || command == null)
          Text(
            command == null ? text : otherLines.join('\n'),
            style: TextStyle(color: c.text1, fontSize: 14, height: 1.6),
          ),
        if (command != null) ...[
          const SizedBox(height: 8),
          _CodeBlock(code: command, onRunInTerminal: onRunInTerminal),
          if (otherLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              otherLines.join('\n'),
              style: TextStyle(color: c.text2, fontSize: 12, height: 1.5),
            ),
          ],
        ],
      ],
    );
  }
}

// ── Bloco de código ──────────────────────────────────────────────────────────

class _CodeBlock extends StatefulWidget {
  final String code;
  final void Function(String)? onRunInTerminal;
  const _CodeBlock({required this.code, this.onRunInTerminal});

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;
  bool _ran = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  Future<void> _run() async {
    widget.onRunInTerminal!(widget.code);
    setState(() => _ran = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _ran = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: c.accent.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              border: Border(
                bottom: BorderSide(
                  color: c.accent.withValues(alpha: 0.16),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded, size: 12, color: c.accent),
                const SizedBox(width: 6),
                Text(
                  'terminal',
                  style: TextStyle(
                    color: c.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (widget.onRunInTerminal != null) ...[
                  GestureDetector(
                    onTap: _ran ? null : _run,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _ran
                          ? Row(
                              key: const ValueKey('ran'),
                              children: [
                                const Icon(Icons.check_rounded,
                                    size: 12, color: Colors.greenAccent),
                                const SizedBox(width: 4),
                                const Text(
                                  'Enviado',
                                  style: TextStyle(
                                      color: Colors.greenAccent, fontSize: 11),
                                ),
                              ],
                            )
                          : Row(
                              key: const ValueKey('run'),
                              children: [
                                Icon(Icons.play_arrow_rounded,
                                    size: 12, color: c.accent),
                                const SizedBox(width: 4),
                                Text(
                                  'Executar',
                                  style: TextStyle(
                                    color: c.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                GestureDetector(
                  onTap: _copy,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _copied
                        ? Row(
                            key: const ValueKey('copied'),
                            children: [
                              Icon(Icons.check_rounded,
                                  size: 12, color: c.accent),
                              const SizedBox(width: 4),
                              Text(
                                'Copiado',
                                style:
                                    TextStyle(color: c.accent, fontSize: 11),
                              ),
                            ],
                          )
                        : Row(
                            key: const ValueKey('copy'),
                            children: [
                              Icon(Icons.copy_rounded,
                                  size: 12, color: c.text2),
                              const SizedBox(width: 4),
                              Text(
                                'Copiar',
                                style:
                                    TextStyle(color: c.text2, fontSize: 11),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: SelectableText(
              widget.code,
              style: const TextStyle(
                color: Color(0xFF7DD8F8),
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bubble de resposta bruta ─────────────────────────────────────────────────

class _RawBubble extends StatefulWidget {
  final String text;
  const _RawBubble({required this.text});

  @override
  State<_RawBubble> createState() => _RawBubbleState();
}

class _RawBubbleState extends State<_RawBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.data_object_rounded,
                      size: 13, color: c.text2),
                  const SizedBox(width: 6),
                  Text(
                    'Resposta bruta da IA',
                    style: TextStyle(color: c.text2, fontSize: 12),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: c.text2,
                  ),
                ],
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: SelectableText(
                  widget.text.replaceFirst('Resposta bruta da IA:\n', ''),
                  style: TextStyle(
                    color: c.text3,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
