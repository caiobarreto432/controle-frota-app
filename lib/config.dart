class ApiConfig {
  /// URL base do servidor Backend.
  static const String baseUrl =
      'https://controle-frota-api-2-production.up.railway.app';

  /// Número oficial do Comandante/Chefe da Companhia para envio dos relatórios em Excel.
  static const String numeroComandanteWhatsApp = '5571999881574';

  static Uri get loginUri => Uri.parse('$baseUrl/login');
  static Uri get viaturasUri => Uri.parse('$baseUrl/viaturas');
  static Uri get registrosUri => Uri.parse('$baseUrl/registros');
  static Uri get policiaisUri => Uri.parse('$baseUrl/policiais');
  static Uri get checklistsUri => Uri.parse('$baseUrl/checklists');

  static Uri viaturaKmUri(String id) => Uri.parse('$baseUrl/viaturas/$id/km');
  static Uri viaturaStatusUri(String id) =>
      Uri.parse('$baseUrl/viaturas/$id/status');
  static Uri viaturaEditarUri(String id) => Uri.parse('$baseUrl/viaturas/$id');
  static Uri checklistsViaturaUri(String id) =>
      Uri.parse('$baseUrl/checklists/viatura/$id');
  static Uri policialDesativarUri(String id) =>
      Uri.parse('$baseUrl/policiais/$id/desativar');
  static Uri get salvarRegistroUri => Uri.parse('$baseUrl/salvar-registro');

  static String checklistExcelUrl(String id) => '$baseUrl/checklists/$id/excel';
  static String registroExcelUrl(String id) => '$baseUrl/registros/$id/excel';

  static String urlFoto(String? caminhoFoto) {
    if (caminhoFoto == null || caminhoFoto.trim().isEmpty) return '';
    if (caminhoFoto.startsWith('http://') ||
        caminhoFoto.startsWith('https://')) {
      return caminhoFoto;
    }
    final limpo = caminhoFoto.trim().replaceAll(RegExp(r'^\/+'), '');
    return '$baseUrl/$limpo';
  }
}
