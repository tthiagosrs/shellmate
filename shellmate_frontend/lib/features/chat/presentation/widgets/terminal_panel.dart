import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

import '../../../../core/theme/app_colors.dart';

// ── Controller público ────────────────────────────────────────────────────────

class TerminalController {
  _TerminalPanelState? _state;
  void runCommand(String cmd) => _state?._runInPty(cmd);
}

// ─────────────────────────────────────────────────────────────────────────────

class TerminalPanel extends StatefulWidget {
  final TerminalController? controller;
  const TerminalPanel({super.key, this.controller});

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  final _terminal = Terminal(maxLines: 10000);
  Pty? _pty;
  bool _exited = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _startShell();
  }

  void _startShell() {
    if (!mounted) return;
    setState(() => _exited = false);

    final shell = Platform.isMacOS
        ? '/bin/zsh'
        : Platform.isWindows
            ? 'cmd.exe'
            : '/bin/bash';

    _pty?.kill();
    _pty = Pty.start(shell, columns: 80, rows: 24);

    _pty!.output
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(_terminal.write);

    _pty!.exitCode.then((_) {
      if (mounted) {
        setState(() => _exited = true);
        _terminal.write(
            '\r\n\r\n[Processo encerrado. Clique em ↺ para reiniciar.]\r\n');
      }
    });

    _terminal.onOutput = (data) => _pty?.write(const Utf8Encoder().convert(data));
    _terminal.onResize = (w, h, pw, ph) => _pty?.resize(h, w);
  }

  void _runInPty(String cmd) {
    _pty?.write(const Utf8Encoder().convert('$cmd\n'));
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _pty?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = c.isDark;
    return Column(
      children: [
        _TerminalHeader(c: c, exited: _exited, onRestart: _startShell),
        Expanded(
          child: ColoredBox(
            color: isDark ? const Color(0xFF0B0D13) : const Color(0xFFF8F9FC),
            child: TerminalView(
              _terminal,
              theme: isDark ? _darkTheme : _lightTheme,
              textStyle: const TerminalStyle(fontSize: 13),
              padding: const EdgeInsets.all(8),
              autofocus: false,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tema escuro (Catppuccin Mocha) ────────────────────────────────────────────

const _darkTheme = TerminalTheme(
  cursor: Color(0xFF5BCEFA),
  selection: Color(0x4D5BCEFA),
  foreground: Color(0xFFCDD6F4),
  background: Color(0xFF0B0D13),
  black: Color(0xFF1E1E2E),
  red: Color(0xFFF38BA8),
  green: Color(0xFFA6E3A1),
  yellow: Color(0xFFF9E2AF),
  blue: Color(0xFF89B4FA),
  magenta: Color(0xFFCBA6F7),
  cyan: Color(0xFF89DCEB),
  white: Color(0xFFBAC2DE),
  brightBlack: Color(0xFF585B70),
  brightRed: Color(0xFFF38BA8),
  brightGreen: Color(0xFFA6E3A1),
  brightYellow: Color(0xFFF9E2AF),
  brightBlue: Color(0xFF89B4FA),
  brightMagenta: Color(0xFFCBA6F7),
  brightCyan: Color(0xFF89DCEB),
  brightWhite: Color(0xFFA6ADC8),
  searchHitBackground: Color(0xFFF9E2AF),
  searchHitBackgroundCurrent: Color(0xFFF38BA8),
  searchHitForeground: Color(0xFF1E1E2E),
);

// ── Tema claro ────────────────────────────────────────────────────────────────

const _lightTheme = TerminalTheme(
  cursor: Color(0xFF1480C8),
  selection: Color(0x4D1480C8),
  foreground: Color(0xFF1A1B28),
  background: Color(0xFFF8F9FC),
  black: Color(0xFF1A1B28),
  red: Color(0xFFD93025),
  green: Color(0xFF1E8E3E),
  yellow: Color(0xFFBF8600),
  blue: Color(0xFF1480C8),
  magenta: Color(0xFF8142A3),
  cyan: Color(0xFF007B83),
  white: Color(0xFF585C72),
  brightBlack: Color(0xFF9EA2B8),
  brightRed: Color(0xFFE8453C),
  brightGreen: Color(0xFF34A853),
  brightYellow: Color(0xFFE8A700),
  brightBlue: Color(0xFF4285F4),
  brightMagenta: Color(0xFFA050C3),
  brightCyan: Color(0xFF00ACC1),
  brightWhite: Color(0xFF1A1B28),
  searchHitBackground: Color(0xFFFEF3C7),
  searchHitBackgroundCurrent: Color(0xFFFDE68A),
  searchHitForeground: Color(0xFF1A1B28),
);

// ── Header do terminal ────────────────────────────────────────────────────────

class _TerminalHeader extends StatelessWidget {
  final AppColors c;
  final bool exited;
  final VoidCallback onRestart;

  const _TerminalHeader({
    required this.c,
    required this.exited,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: c.bgSidebar,
        border: Border(
          bottom: BorderSide(color: c.divider, width: 0.5),
          left: BorderSide(color: c.divider, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // Traffic-light dots
          _TrafficDot(color: const Color(0xFFFF5F56)),
          SizedBox(width: 6),
          _TrafficDot(color: const Color(0xFFFFBD2E)),
          SizedBox(width: 6),
          _TrafficDot(color: const Color(0xFF27C840)),
          const SizedBox(width: 14),
          // Ícone
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accentDim,
              border: Border.all(color: c.accentBorder, width: 0.5),
            ),
            child: Icon(Icons.terminal_rounded, size: 12, color: c.accent),
          ),
          const SizedBox(width: 8),
          Text(
            'Terminal',
            style: TextStyle(
              color: c.text1,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (exited) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: const Text(
                'encerrado',
                style: TextStyle(color: Colors.redAccent, fontSize: 10),
              ),
            ),
          ],
          const Spacer(),
          // Reiniciar
          GestureDetector(
            onTap: onRestart,
            child: Tooltip(
              message: 'Reiniciar shell',
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accentDim,
                  border: Border.all(color: c.accentBorder, width: 0.5),
                ),
                child:
                    Icon(Icons.refresh_rounded, size: 14, color: c.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficDot extends StatelessWidget {
  final Color color;
  const _TrafficDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
