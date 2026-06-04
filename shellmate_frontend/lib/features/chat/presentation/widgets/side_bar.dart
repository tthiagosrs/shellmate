import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_notifier.dart';
import '../../../historico/data/historico_service.dart';

class SideBar extends StatefulWidget {
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectCommand;

  const SideBar({
    super.key,
    required this.onNewChat,
    required this.onSelectCommand,
  });

  @override
  SideBarState createState() => SideBarState();
}

class SideBarState extends State<SideBar> {
  final _service = HistoricoService();
  List<HistoricoItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void refresh() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final items = await _service.listar(limite: 40);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await _service.excluir(id);
      if (mounted) setState(() => _items.removeWhere((i) => i.id == id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao excluir: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _clearAll(BuildContext context) async {
    final c = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border, width: 0.5),
        ),
        title: Text('Limpar histórico',
            style: TextStyle(color: c.text1, fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
          'Remover todos os ${_items.length} registros permanentemente?',
          style: TextStyle(color: c.text2, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: c.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar tudo',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _service.limparTudo();
        if (mounted) setState(() => _items.clear());
      } catch (_) {}
    }
  }

  String get _username =>
      Platform.environment['USER'] ??
      Platform.environment['USERNAME'] ??
      'usuário';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: c.bgSidebar,
        border: Border(right: BorderSide(color: c.divider, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Logo(c: c),
          const SizedBox(height: 16),
          _NewChatButton(c: c, onTap: widget.onNewChat),
          const SizedBox(height: 20),
          _SectionHeader(
            c: c,
            label: 'Histórico',
            onRefresh: _load,
            onClear: _items.isEmpty ? null : () => _clearAll(context),
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildList(c)),
          Container(height: 0.5, color: c.divider),
          _UserTile(c: c, username: _username),
        ],
      ),
    );
  }

  Widget _buildList(AppColors c) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: c.accent),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text('Nenhum histórico ainda',
            style: TextStyle(color: c.text3, fontSize: 12)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: _items.length,
      itemBuilder: (_, i) => _HistoricoTile(
        key: ValueKey(_items[i].id),
        item: _items[i],
        onTap: () => widget.onSelectCommand(_items[i].inputUsuario),
        onDelete: () => _deleteItem(_items[i].id),
      ),
    );
  }
}

// ── Logo ──────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  final AppColors c;
  const _Logo({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1A3A5C), Color(0xFF08141E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                  color: c.accent.withValues(alpha: 0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.2),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.terminal_rounded, size: 19, color: c.accent),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: [c.accent, const Color(0xFF8BB4FF)],
                ).createShader(b),
                blendMode: BlendMode.srcIn,
                child: const Text(
                  'Shellmate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text('Terminal AI',
                  style: TextStyle(
                      color: c.text3,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Botão Novo Chat ───────────────────────────────────────────────────────────

class _NewChatButton extends StatefulWidget {
  final AppColors c;
  final VoidCallback onTap;
  const _NewChatButton({required this.c, required this.onTap});

  @override
  State<_NewChatButton> createState() => _NewChatButtonState();
}

class _NewChatButtonState extends State<_NewChatButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: c.isDark
                    ? (_hover
                        ? [const Color(0xFF1E4A72), const Color(0xFF102840)]
                        : [const Color(0xFF14304A), const Color(0xFF0A1E2E)])
                    : (_hover
                        ? [const Color(0xFF1890DE), const Color(0xFF1070B0)]
                        : [const Color(0xFF1480C8), const Color(0xFF0D68A0)]),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: c.accent.withValues(alpha: _hover ? 0.5 : 0.28),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: _hover ? 0.14 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Novo Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Cabeçalho de seção ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final AppColors c;
  final String label;
  final VoidCallback onRefresh;
  final VoidCallback? onClear;
  const _SectionHeader(
      {required this.c,
      required this.label,
      required this.onRefresh,
      this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.text3,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.delete_sweep_rounded,
                    size: 14, color: c.text3),
              ),
            ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onRefresh,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.refresh_rounded, size: 14, color: c.text3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item de histórico ─────────────────────────────────────────────────────────

class _HistoricoTile extends StatefulWidget {
  final HistoricoItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _HistoricoTile(
      {super.key,
      required this.item,
      required this.onTap,
      required this.onDelete});

  @override
  State<_HistoricoTile> createState() => _HistoricoTileState();
}

class _HistoricoTileState extends State<_HistoricoTile> {
  bool _hover = false;

  String _timeAgo(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'agora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final timeAgo = _timeAgo(widget.item.dataHora);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _hover ? c.accentDim : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hover ? c.accentBorder : Colors.transparent,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.item.executado
                    ? Icons.check_circle_outline_rounded
                    : Icons.terminal_rounded,
                size: 11,
                color: widget.item.executado
                    ? Colors.green.withValues(alpha: 0.7)
                    : c.text3,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.item.inputUsuario,
                  style: TextStyle(
                    color: _hover ? c.text1 : c.text2,
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              // Mostra X no hover, tempo quando não
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: _hover
                    ? GestureDetector(
                        key: const ValueKey('del'),
                        onTap: widget.onDelete,
                        child: Icon(Icons.close_rounded,
                            size: 13, color: c.text2),
                      )
                    : (timeAgo.isNotEmpty
                        ? Text(
                            key: const ValueKey('time'),
                            timeAgo,
                            style: TextStyle(color: c.text3, fontSize: 10),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty'))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Seção do usuário ──────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final AppColors c;
  final String username;
  const _UserTile({required this.c, required this.username});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2535), Color(0xFF0E1520)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                  color: c.accent.withValues(alpha: 0.22), width: 0.5),
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: c.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username,
                    style: TextStyle(
                        color: c.text1,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
                Text(PlatformInfo.displayName,
                    style: TextStyle(color: c.text3, fontSize: 10)),
              ],
            ),
          ),
          // Toggle tema
          ValueListenableBuilder<bool>(
            valueListenable: themeNotifier,
            builder: (_, isDark, _) => GestureDetector(
              onTap: () => themeNotifier.value = !themeNotifier.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accentDim,
                  border:
                      Border.all(color: c.accentBorder, width: 0.5),
                ),
                child: Icon(
                  isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  size: 14,
                  color: c.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
