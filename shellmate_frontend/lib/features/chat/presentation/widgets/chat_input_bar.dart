import 'package:flutter/material.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final String selectedModel;
  final String selectedMode;
  final bool runCommand;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<bool> onRunCommandChanged;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.selectedModel,
    required this.selectedMode,
    required this.runCommand,
    required this.onModelChanged,
    required this.onModeChanged,
    required this.onRunCommandChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _focusNode = FocusNode();
  bool _focused = false;

  static const _modelOptions = <String, String>{
    'Gemini': 'Gemini',
    'Groq': 'Groq',
  };

  static const _modeOptions = <String, String>{
    'tecnico': 'Técnico',
    'resumido': 'Resumido',
    'professor': 'Professor',
    'detalhado': 'Detalhado',
    'suporte': 'Suporte',
  };

  static const _modeIcons = <String, IconData>{
    'tecnico': Icons.code_rounded,
    'resumido': Icons.compress_rounded,
    'professor': Icons.school_rounded,
    'detalhado': Icons.manage_search_rounded,
    'suporte': Icons.support_agent_rounded,
  };

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
        () => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _focused ? c.accentFocus : c.border,
            width: 1,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: c.accentDim,
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    style: TextStyle(
                      color: c.text1,
                      fontSize: 14,
                      height: 1.55,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Pergunte ao Shellmate...',
                      hintStyle: TextStyle(color: c.text3),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.fromLTRB(16, 10, 0, 10),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => widget.onSend(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
                  child: _SendButton(
                    sending: widget.sending,
                    onTap: widget.sending ? null : widget.onSend,
                    accent: c.accent,
                  ),
                ),
              ],
            ),
            Container(height: 0.5, color: c.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Row(
                children: [
                  _DropdownChip(
                    icon: Icons.auto_awesome_rounded,
                    label: _modelOptions[widget.selectedModel] ??
                        widget.selectedModel,
                    items: _modelOptions,
                    onSelected: widget.onModelChanged,
                  ),
                  const SizedBox(width: 7),
                  _DropdownChip(
                    icon: _modeIcons[widget.selectedMode] ??
                        Icons.tune_rounded,
                    label: _modeOptions[widget.selectedMode] ??
                        widget.selectedMode,
                    items: _modeOptions,
                    onSelected: widget.onModeChanged,
                  ),
                  const Spacer(),
                  _ExecuteChip(
                    active: widget.runCommand,
                    onTap: () =>
                        widget.onRunCommandChanged(!widget.runCommand),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botão de envio ───────────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  final bool sending;
  final VoidCallback? onTap;
  final Color accent;

  const _SendButton(
      {required this.sending, this.onTap, required this.accent});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color:
              enabled ? accent : accent.withValues(alpha: 0.24),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: sending
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0A1A22),
                  ),
                )
              : const Icon(
                  Icons.arrow_upward_rounded,
                  size: 17,
                  color: Color(0xFF0A1A22),
                ),
        ),
      ),
    );
  }
}

// ── Chip com dropdown ────────────────────────────────────────────────────────

class _DropdownChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Map<String, String> items;
  final ValueChanged<String> onSelected;

  const _DropdownChip({
    required this.icon,
    required this.label,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: c.bgSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
      itemBuilder: (_) => items.entries
          .map(
            (e) => PopupMenuItem<String>(
              value: e.key,
              child: Text(e.value,
                  style: TextStyle(color: c.text1, fontSize: 13)),
            ),
          )
          .toList(),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: c.accent),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: c.text1,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: c.text2),
          ],
        ),
      ),
    );
  }
}

// ── Chip de execução (toggle) ────────────────────────────────────────────────

class _ExecuteChip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _ExecuteChip({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? c.accentSub : c.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? c.accentStrong : c.border,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.terminal_rounded,
              size: 13,
              color: active ? c.accent : c.text3,
            ),
            const SizedBox(width: 5),
            Text(
              'Executar no ${PlatformInfo.displayName}',
              style: TextStyle(
                color: active ? c.accent : c.text3,
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
