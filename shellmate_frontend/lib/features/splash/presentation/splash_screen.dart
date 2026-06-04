import 'package:flutter/material.dart';

import '../../../core/server/server_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../chat/presentation/chat_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Iniciando o Shellmate...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _status = 'Iniciando o Shellmate...';
      _hasError = false;
    });
    try {
      await startServer();
      if (mounted) setState(() => _status = 'Conectando ao servidor...');
      await waitForServer();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Erro ao iniciar o servidor:\n$e';
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Shellmate',
              style: TextStyle(
                color: c.accent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seu assistente de terminal',
              style: TextStyle(color: c.text2, fontSize: 14),
            ),
            const SizedBox(height: 48),
            if (!_hasError)
              CircularProgressIndicator(color: c.accent)
            else
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 48),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _status,
                style: TextStyle(color: c.text2, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            if (_hasError) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _boot,
                icon: Icon(Icons.refresh, color: c.accent),
                label: Text(
                  'Tentar novamente',
                  style: TextStyle(color: c.accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
