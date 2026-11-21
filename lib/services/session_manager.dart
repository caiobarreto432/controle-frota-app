import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Gerenciador centralizado e seguro de sessão do usuário.
/// Utiliza criptografia nativa no dispositivo (Keystore no Android / Keychain no iOS).
class SessionManager {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _keyLogado = 'logado';
  static const String _keyMatricula = 'matricula';
  static const String _keyNome = 'nome';
  static const String _keyPerfil = 'perfil';
  static const String _keyToken = 'token';
  static const String _keyPlantaoAtivo = 'plantao_ativo';

  /// Salva os dados de autenticação de forma segura e criptografada.
  static Future<void> saveSession({
    required String matricula,
    required String nome,
    required String perfil,
    String? token,
  }) async {
    final futures = <Future<void>>[
      _storage.write(key: _keyLogado, value: 'true'),
      _storage.write(key: _keyMatricula, value: matricula.trim()),
      _storage.write(key: _keyNome, value: nome.trim()),
      _storage.write(key: _keyPerfil, value: perfil.trim().toUpperCase()),
    ];
    if (token != null && token.isNotEmpty) {
      futures.add(_storage.write(key: _keyToken, value: token.trim()));
    }
    await Future.wait(futures);
  }

  /// Verifica se o usuário possui sessão ativa.
  static Future<bool> isLoggedIn() async {
    final logado = await _storage.read(key: _keyLogado);
    final matricula = await _storage.read(key: _keyMatricula);
    return logado == 'true' || (matricula != null && matricula.trim().isNotEmpty);
  }

  /// Retorna a matrícula do policial logado.
  static Future<String> getMatricula() async {
    return (await _storage.read(key: _keyMatricula))?.trim() ?? '';
  }

  /// Retorna o nome do policial logado.
  static Future<String> getNome() async {
    return (await _storage.read(key: _keyNome))?.trim() ?? '';
  }

  /// Retorna o perfil do policial logado (ex: "ADMIN", "POLICIAL").
  static Future<String> getPerfil() async {
    final perfil = await _storage.read(key: _keyPerfil);
    return (perfil != null && perfil.trim().isNotEmpty)
        ? perfil.trim().toUpperCase()
        : 'POLICIAL';
  }

  /// Retorna o token JWT armazenado.
  static Future<String> getToken() async {
    return (await _storage.read(key: _keyToken))?.trim() ?? '';
  }

  /// Retorna os cabeçalhos padrão para requisições de API com token Bearer e matrícula.
  static Future<Map<String, String>> getAuthHeaders({
    bool includeJsonContentType = true,
  }) async {
    final token = await getToken();
    final matricula = await getMatricula();
    final perfil = await getPerfil();

    final headers = <String, String>{};
    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (matricula.isNotEmpty) {
      headers['x-matricula'] = matricula;
      if (perfil == 'ADMIN') {
        headers['x-admin-matricula'] = matricula;
      }
    }
    return headers;
  }

  /// Verifica se o usuário atual é Administrador.
  static Future<bool> isAdmin() async {
    final perfil = await getPerfil();
    return perfil == 'ADMIN';
  }

  /// Salva o estado do plantão em andamento para não perder os dados ao fechar o app.
  static Future<void> savePlantaoAtivo(Map<String, dynamic> dados) async {
    try {
      await _storage.write(
        key: _keyPlantaoAtivo,
        value: jsonEncode(dados),
      );
    } catch (_) {}
  }

  /// Recupera o estado do plantão em andamento salvo localmente, se houver.
  static Future<Map<String, dynamic>?> getPlantaoAtivo() async {
    try {
      final raw = await _storage.read(key: _keyPlantaoAtivo);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Limpa os dados locais do plantão em andamento após salvar o registro.
  static Future<void> clearPlantaoAtivo() async {
    try {
      await _storage.delete(key: _keyPlantaoAtivo);
    } catch (_) {}
  }

  /// Encerra a sessão e limpa todos os dados armazenados com segurança.
  static Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
