import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/historico_service.dart';

class HistoricoItemTile extends StatelessWidget {
  final HistoricoItem item;
  final VoidCallback? onUseCommand;
  final VoidCallback? onDelete;

  const HistoricoItemTile({
    super.key,
    required this.item,
    this.onUseCommand,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dataFormatada =
        item.dataHora.length > 16 ? item.dataHora.substring(0, 16) : item.dataHora;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.inputUsuario,
                    style: TextStyle(
                      color: c.text1,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  item.executado
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: item.executado ? c.accent : c.text2,
                  size: 14,
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0C12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.comandoGerado,
              style: const TextStyle(
                color: Color(0xFF7DD8F8),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 8),
            child: Row(
              children: [
                Text(
                  '${item.sistemaOperacional} · $dataFormatada',
                  style: TextStyle(color: c.text2, fontSize: 11),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: item.comandoGerado));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Comando copiado!'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: c.bgSurface,
                      ),
                    );
                  },
                  icon: Icon(Icons.copy, size: 16, color: c.text2),
                  tooltip: 'Copiar',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                ),
                if (onUseCommand != null)
                  IconButton(
                    onPressed: onUseCommand,
                    icon: Icon(Icons.send, size: 16, color: c.accent),
                    tooltip: 'Usar no chat',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.redAccent),
                    tooltip: 'Excluir',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
