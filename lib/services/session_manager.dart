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
    return logado == 'true';
  }

  /// Retorna a matrícula do policial logado.
  static Future<String> getMatricula() async {
    return (await _storage.read(key: _keyMatricula)) ?? '';
  }

  /// Retorna o nome do policial logado.
  static Future<String> getNome() async {
    return (await _storage.read(key: _keyNome)) ?? '';
  }

  /// Retorna o perfil do policial logado (ex: "ADMIN", "POLICIAL").
  static Future<String> getPerfil() async {
    final perfil = await _storage.read(key: _keyPerfil);
    return (perfil != null && perfil.isNotEmpty)
        ? perfil.toUpperCase()
        : 'POLICIAL';
  }

  /// Retorna o token JWT armazenado.
  static Future<String> getToken() async {
    return (await _storage.read(key: _keyToken)) ?? '';
  }

  /// Retorna os cabeçalhos padrão para requisições de API com token Bearer se disponível.
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer ';
    }
    return headers;
  }

  /// Verifica se o usuário atual é Administrador.
  static Future<bool> isAdmin() async {
    final perfil = await getPerfil();
    return perfil == 'ADMIN';
  }

  /// Encerra a sessão e limpa todos os dados armazenados com segurança.
  static Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
