import 'dart:io';

abstract final class PlatformInfo {
  /// Valor enviado à API: 'Windows', 'Linux' ou 'Darwin'
  static String get sistema {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'Darwin';
    return 'Linux';
  }

  /// Nome legível para exibir na UI
  static String get displayName {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    return 'Linux';
  }

  /// Shell padrão para executar comandos
  static String get shell {
    if (Platform.isWindows) return 'powershell';
    return 'bash';
  }

  /// Versão curta do SO (ex: "macOS 15.3", "Windows 11", "Ubuntu 24.04")
  static String get version {
    final raw = Platform.operatingSystemVersion;
    if (Platform.isMacOS) {
      // "Version 15.3.1 (Build 24D70)" → "15.3.1"
      final match = RegExp(r'Version\s+([\d.]+)').firstMatch(raw);
      return match != null ? 'macOS ${match.group(1)}' : 'macOS';
    }
    if (Platform.isWindows) {
      // "Windows 10 Pro 10.0 (Build 19045)" → pega a primeira parte
      final match = RegExp(r'(Windows\s+\S+)').firstMatch(raw);
      return match?.group(1) ?? 'Windows';
    }
    // Linux: retorna o que vier (costuma ser curtinho)
    return raw.length > 30 ? raw.substring(0, 30) : raw;
  }
}
