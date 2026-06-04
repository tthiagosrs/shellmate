import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../data/historico_service.dart';
import 'widgets/historico_item_tile.dart';

class HistoricoScreen extends StatefulWidget {
  final void Function(String comando)? onUseCommand;

  const HistoricoScreen({super.key, this.onUseCommand});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final _service = HistoricoService();
  final _searchController = TextEditingController();

  List<HistoricoItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _service.listar();
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _excluir(int id) async {
    try {
      await _service.excluir(id);
      setState(() => _items.removeWhere((i) => i.id == id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _limparTudo() async {
    if (_items.isEmpty) return;
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
            style: TextStyle(
                color: c.text1, fontSize: 16, fontWeight: FontWeight.w600)),
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
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _service.limparTudo();
        if (mounted) setState(() => _items.clear());
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao limpar: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _buscar(String termo) async {
    if (termo.trim().isEmpty) { _load(); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _service.buscar(termo.trim());
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text('Histórico',
            style: TextStyle(color: c.text1, fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: false,
        iconTheme: IconThemeData(color: c.text2),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              onPressed: _limparTudo,
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: Colors.redAccent),
              tooltip: 'Limpar tudo',
            ),
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh, color: c.text2),
            tooltip: 'Atualizar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: c.border),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: c.bgSurface,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: c.text1, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar no histórico...',
                hintStyle: TextStyle(color: c.text2),
                prefixIcon: Icon(Icons.search, color: c.text2, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: c.text2, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                      )
                    : null,
                filled: true,
                fillColor: c.bg,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.accent),
                ),
              ),
              onChanged: (v) {
                setState(() {});
                if (v.isEmpty) _load();
              },
              onSubmitted: _buscar,
              textInputAction: TextInputAction.search,
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(child: _buildBody(c)),
        ],
      ),
    );
  }

  Widget _buildBody(AppColors c) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: c.accent));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: c.text2, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _load,
              icon: Icon(Icons.refresh, color: c.accent),
              label: Text('Tentar novamente',
                  style: TextStyle(color: c.accent)),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text('Nenhum registro encontrado.',
            style: TextStyle(color: c.text2, fontSize: 14)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (_, i) => HistoricoItemTile(
        item: _items[i],
        onUseCommand: widget.onUseCommand != null
            ? () {
                widget.onUseCommand!(_items[i].comandoGerado);
                Navigator.of(context).pop();
              }
            : null,
        onDelete: () => _excluir(_items[i].id),
      ),
    );
  }
}
