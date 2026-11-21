import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelExporter {
  /// Gera a planilha Excel (.xlsx) do Registro de Viatura diretamente no celular
  static Future<File> gerarExcelRegistro({
    required Map<String, dynamic> registro,
    Map<String, dynamic>? viatura,
    List<dynamic>? itensChecklist,
    Map<String, dynamic>? checklistSaida,
    Map<String, dynamic>? checklistRetorno,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Registro de Viatura';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final headerStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 14,
    );

    final sectionStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 12,
    );

    final labelStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 10,
    );

    int row = 0;

    void addLinhaTitulo(String titulo) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      cell.value = TextCellValue(titulo);
      cell.cellStyle = headerStyle;
      row++;
    }

    void addLinhaSecao(String secao) {
      row++;
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      cell.value = TextCellValue(secao);
      cell.cellStyle = sectionStyle;
      row++;
    }

    void addLinhaDupla(String label1, dynamic val1, String label2, dynamic val2) {
      final c0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      c0.value = TextCellValue(label1);
      c0.cellStyle = labelStyle;

      final c1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      c1.value = TextCellValue(val1?.toString() ?? '-');

      final c2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      c2.value = TextCellValue(label2);
      c2.cellStyle = labelStyle;

      final c3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
      c3.value = TextCellValue(val2?.toString() ?? '-');

      row++;
    }

    void addLinhaSimples(String label, dynamic val) {
      final c0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      c0.value = TextCellValue(label);
      c0.cellStyle = labelStyle;

      final c1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      c1.value = TextCellValue(val?.toString() ?? '-');

      row++;
    }

    // Cabeçalho
    addLinhaTitulo('POLÍCIA MILITAR DA BAHIA');
    addLinhaTitulo('SISTEMA DE CONTROLE DE FROTA • REGISTRO DE USO DE VIATURA');

    // 1. Dados do Registro
    addLinhaSecao('1. DADOS DO REGISTRO E DA VIATURA');
    final prefixo = registro['prefixo_viatura']?.toString() ?? viatura?['prefixo']?.toString() ?? '-';
    final placa = registro['placa_viatura']?.toString() ?? viatura?['placa']?.toString() ?? '-';
    final dataServico = registro['data_servico']?.toString() ?? DateTime.now().toString().substring(0, 10);
    final regId = registro['id']?.toString() ?? 'Novo';

    addLinhaDupla('Protocolo/ID:', '#$regId', 'Data do Serviço:', dataServico);
    addLinhaDupla('Prefixo da Viatura:', prefixo, 'Placa Oficial:', placa);
    if (viatura != null) {
      final modelo = '${viatura['marca'] ?? ''} ${viatura['modelo'] ?? ''}'.trim();
      addLinhaDupla('Modelo/Marca:', modelo.isEmpty ? '-' : modelo, 'Tipo:', viatura['tipo']?.toString() ?? 'CARRO');
    }

    // 2. Policial Responsável
    addLinhaSecao('2. POLICIAL RESPONSÁVEL');
    final nomePolicial = registro['nome_policial']?.toString() ?? '-';
    final matricula = registro['matricula']?.toString() ?? '-';
    addLinhaDupla('Nome:', nomePolicial, 'Matrícula:', matricula);

    // 3. Quilometragem e Abastecimento
    addLinhaSecao('3. QUILOMETRAGEM E ABASTECIMENTO');
    final kmIni = double.tryParse(registro['km_inicial']?.toString() ?? '0') ?? 0.0;
    final kmFim = double.tryParse(registro['km_final']?.toString() ?? '0') ?? 0.0;
    final kmRodado = kmFim >= kmIni ? (kmFim - kmIni) : 0.0;

    final litros = double.tryParse(registro['combustivel_inicial']?.toString() ?? '0') ?? 0.0;
    final valorAbast = double.tryParse(registro['combustivel_final']?.toString() ?? '0') ?? 0.0;
    final houveAbastecimento = litros > 0 || valorAbast > 0;

    addLinhaDupla('KM Inicial:', '${kmIni.toInt()} km', 'KM Final:', '${kmFim.toInt()} km');
    addLinhaDupla('Distância Percorrida:', '${kmRodado.toInt()} km', 'Abasteceu?:', houveAbastecimento ? 'SIM' : 'NÃO');

    if (houveAbastecimento) {
      addLinhaDupla(
        'Litros Abastecidos:',
        '${litros.toStringAsFixed(2)} L',
        'Valor Pago:',
        'R\$ ${valorAbast.toStringAsFixed(2)}',
      );
    }

    // 4. Avarias e Observações
    addLinhaSecao('4. AVARIAS E OBSERVAÇÕES');
    final avarias = registro['ocorrencias']?.toString().trim() ?? '';
    final obs = registro['observacoes']?.toString().trim() ?? '';
    addLinhaSimples('Avarias/Ocorrências:', avarias.isEmpty ? 'Nenhuma avaria relatada' : avarias);
    addLinhaSimples('Observações Gerais:', obs.isEmpty ? 'Nenhuma' : obs);

    // 5. Vistorias e Itens do Checklist
    if (checklistSaida != null || checklistRetorno != null) {
      addLinhaSecao('5. VISTORIAS E CHECKLISTS DO SERVIÇO');
      final statusS = checklistSaida?['status']?.toString().toUpperCase() ?? 'OK';
      final statusR = checklistRetorno?['status']?.toString().toUpperCase() ?? 'OK';
      addLinhaDupla(
        'Checklist de Saída (Pegar):',
        checklistSaida != null ? (statusS == 'OK' ? 'APROVADO (OK)' : 'COM PROBLEMA') : 'Concluído',
        'Checklist Devolução (Terminar):',
        checklistRetorno != null ? (statusR == 'OK' ? 'APROVADO (OK)' : 'COM PROBLEMA') : 'Concluído',
      );
    }

    if (itensChecklist != null && itensChecklist.isNotEmpty) {
      addLinhaSecao('6. ITENS INSPECIONADOS');
      final cItem = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      cItem.value = TextCellValue('Item');
      cItem.cellStyle = labelStyle;

      final cStatus = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      cStatus.value = TextCellValue('Situação');
      cStatus.cellStyle = labelStyle;

      final cObs = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      cObs.value = TextCellValue('Observação');
      cObs.cellStyle = labelStyle;
      row++;

      for (final it in itensChecklist) {
        final nome = it['item']?.toString() ?? '';
        final st = it['status']?.toString() ?? 'OK';
        final ob = it['observacao']?.toString() ?? '';

        final r0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
        r0.value = TextCellValue(nome);
        final r1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
        r1.value = TextCellValue(st);
        final r2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
        r2.value = TextCellValue(ob.isEmpty ? '-' : ob);
        row++;
      }
    }

    // Largura aproximada das colunas
    sheet.setColumnWidth(0, 26.0);
    sheet.setColumnWidth(1, 32.0);
    sheet.setColumnWidth(2, 26.0);
    sheet.setColumnWidth(3, 30.0);

    // Salvar em arquivo no dispositivo
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Não foi possível codificar a planilha Excel.');
    }

    final dir = await getTemporaryDirectory();
    final prefixoSanitizado = prefixo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dataHoje = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'Registro_${prefixoSanitizado}_$dataHoje.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Gera a planilha Excel (.xlsx) do Checklist de Viatura diretamente no celular
  static Future<File> gerarExcelChecklist({
    required Map<String, dynamic> viatura,
    required String matriculaPolicial,
    required String nomePolicial,
    required String statusGeral,
    required String km,
    required String observacao,
    required List<Map<String, String>> itens,
    String tipo = 'SAIDA',
  }) async {
    final isRetorno = tipo.toUpperCase() == 'RETORNO';
    final tipoDescricao = isRetorno
        ? 'CHECKLIST DE DEVOLUÇÃO (TÉRMINO DE SERVIÇO)'
        : 'CHECKLIST DE ASSUNÇÃO (AO PEGAR VIATURA)';

    final excel = Excel.createExcel();
    final sheetName = isRetorno ? 'Devolucao' : 'Assuncao';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final headerStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 14,
    );

    final sectionStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 12,
    );

    final labelStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 10,
    );

    int row = 0;

    void addLinhaTitulo(String titulo) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      cell.value = TextCellValue(titulo);
      cell.cellStyle = headerStyle;
      row++;
    }

    void addLinhaSecao(String secao) {
      row++;
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      cell.value = TextCellValue(secao);
      cell.cellStyle = sectionStyle;
      row++;
    }

    void addLinhaDupla(String label1, dynamic val1, String label2, dynamic val2) {
      final c0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      c0.value = TextCellValue(label1);
      c0.cellStyle = labelStyle;

      final c1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      c1.value = TextCellValue(val1?.toString() ?? '-');

      final c2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      c2.value = TextCellValue(label2);
      c2.cellStyle = labelStyle;

      final c3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
      c3.value = TextCellValue(val2?.toString() ?? '-');

      row++;
    }

    addLinhaTitulo('POLÍCIA MILITAR DA BAHIA');
    addLinhaTitulo('SISTEMA DE CONTROLE DE FROTA • $tipoDescricao');

    addLinhaSecao('1. DADOS DO CHECKLIST E VIATURA');
    final prefixo = viatura['prefixo']?.toString() ?? '-';
    final placa = viatura['placa']?.toString() ?? '-';
    final dataHoje = DateTime.now().toLocal().toString().substring(0, 16);

    addLinhaDupla('Prefixo:', prefixo, 'Placa:', placa);
    addLinhaDupla(
      'Tipo de Vistoria:',
      isRetorno ? 'Devolução (Término)' : 'Assunção (Ao Pegar)',
      isRetorno ? 'KM Final (Devolução):' : 'KM Inicial (Assunção):',
      '$km km',
    );
    addLinhaDupla('Status Geral:', statusGeral, 'Data da Vistoria:', dataHoje);
    addLinhaDupla('Policial:', nomePolicial, 'Matrícula:', matriculaPolicial);

    addLinhaSecao('2. CONFERÊNCIA DOS ITENS');
    final cItem = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    cItem.value = TextCellValue('Item Avaliado');
    cItem.cellStyle = labelStyle;

    final cStatus = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    cStatus.value = TextCellValue('Situação');
    cStatus.cellStyle = labelStyle;

    final cObs = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    cObs.value = TextCellValue('Observações');
    cObs.cellStyle = labelStyle;
    row++;

    for (final it in itens) {
      final r0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      r0.value = TextCellValue(it['item'] ?? '');
      final r1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      r1.value = TextCellValue(it['status'] ?? 'OK');
      final r2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      r2.value = TextCellValue(it['observacao']?.isNotEmpty == true ? it['observacao']! : '-');
      row++;
    }

    if (observacao.trim().isNotEmpty) {
      addLinhaSecao('3. OBSERVAÇÕES GERAIS');
      final c0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      c0.value = TextCellValue('Observação:');
      c0.cellStyle = labelStyle;

      final c1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      c1.value = TextCellValue(observacao.trim());
      row++;
    }

    sheet.setColumnWidth(0, 26.0);
    sheet.setColumnWidth(1, 20.0);
    sheet.setColumnWidth(2, 35.0);
    sheet.setColumnWidth(3, 20.0);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Não foi possível codificar a planilha Excel.');
    }

    final dir = await getTemporaryDirectory();
    final prefixoSanitizado = prefixo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dataIso = DateTime.now().toIso8601String().substring(0, 10);
    final tagTipo = isRetorno ? 'Devolucao' : 'Saida';
    final fileName = 'Checklist_${tagTipo}_${prefixoSanitizado}_$dataIso.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Gera uma planilha Excel (.xlsx) consolidada com múltiplos registros filtrados do histórico.
  static Future<File> gerarExcelHistoricoConsolidado({
    required List<Map<String, dynamic>> registros,
    String filtroDescricao = 'Todos os registros',
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Historico Frota';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final headerStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 14,
    );

    final sectionStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 12,
    );

    final labelStyle = CellStyle(
      bold: true,
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 10,
    );

    double parseNum(dynamic valor) {
      if (valor == null) return 0;
      if (valor is num) return valor.toDouble();
      return double.tryParse(valor.toString().replaceAll(',', '.')) ?? 0;
    }

    String formatarNum(double n) {
      if (n == n.roundToDouble()) return n.toInt().toString();
      return n.toStringAsFixed(2).replaceAll('.', ',');
    }

    double totalKmRodado = 0;
    double totalLitros = 0;
    double totalValor = 0;

    for (final reg in registros) {
      final kmIni = parseNum(reg['km_inicial']);
      final kmFim = parseNum(reg['km_final']);
      if (kmFim >= kmIni) {
        totalKmRodado += (kmFim - kmIni);
      }
      totalLitros += parseNum(reg['combustivel_inicial']);
      totalValor += parseNum(reg['combustivel_final']);
    }

    int row = 0;

    void addLinhaTitulo(String titulo) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      cell.value = TextCellValue(titulo);
      cell.cellStyle = headerStyle;
      row++;
    }

    void addLinhaSecao(String secao) {
      row++;
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      cell.value = TextCellValue(secao);
      cell.cellStyle = sectionStyle;
      row++;
    }

    void addLinhaDupla(String l1, String v1, String l2, String v2) {
      final c0 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      c0.value = TextCellValue(l1);
      c0.cellStyle = labelStyle;

      final c1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
      c1.value = TextCellValue(v1);

      final c2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
      c2.value = TextCellValue(l2);
      c2.cellStyle = labelStyle;

      final c3 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
      c3.value = TextCellValue(v2);

      row++;
    }

    addLinhaTitulo('POLÍCIA MILITAR DA BAHIA');
    addLinhaTitulo('SISTEMA DE CONTROLE DE FROTA • RELATÓRIO CONSOLIDADO DE SERVIÇOS');

    addLinhaSecao('1. RESUMO DO PERÍODO');
    final dataGeracao = DateTime.now().toLocal().toString().substring(0, 16);
    addLinhaDupla('Filtro Aplicado:', filtroDescricao, 'Gerado em:', dataGeracao);
    addLinhaDupla('Total de Registros:', '${registros.length}', 'Total KM Rodado:', '${formatarNum(totalKmRodado)} km');
    addLinhaDupla(
      'Total Combustível:',
      '${totalLitros.toStringAsFixed(2).replaceAll('.', ',')} L',
      'Gasto Total:',
      'R\$ ${totalValor.toStringAsFixed(2).replaceAll('.', ',')}',
    );

    addLinhaSecao('2. LISTAGEM DE REGISTROS');
    const cabecalhos = [
      'Data',
      'Prefixo',
      'Placa',
      'Policial',
      'Matrícula',
      'KM Inicial',
      'KM Final',
      'KM Rodado',
      'Litros',
      'Valor (R\$)',
      'Avarias',
      'Observações',
    ];

    for (int col = 0; col < cabecalhos.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      cell.value = TextCellValue(cabecalhos[col]);
      cell.cellStyle = labelStyle;
    }
    row++;

    for (final reg in registros) {
      final dataBruta = (reg['data_servico'] ?? reg['criado_em'] ?? '').toString();
      String dataExibida = '-';
      if (dataBruta.isNotEmpty) {
        final parsed = DateTime.tryParse(dataBruta);
        if (parsed != null) {
          final local = parsed.toLocal();
          dataExibida =
              '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
        } else {
          dataExibida = dataBruta;
        }
      }

      final kmIni = parseNum(reg['km_inicial']);
      final kmFim = parseNum(reg['km_final']);
      final kmRod = kmFim >= kmIni ? (kmFim - kmIni) : 0.0;
      final litros = parseNum(reg['combustivel_inicial']);
      final valor = parseNum(reg['combustivel_final']);
      final avarias = (reg['ocorrencias'] ?? '').toString().trim();
      final obs = (reg['observacoes'] ?? '').toString().trim();

      final valores = [
        dataExibida,
        (reg['prefixo_viatura'] ?? '-').toString(),
        (reg['placa_viatura'] ?? '-').toString(),
        (reg['nome_policial'] ?? '-').toString(),
        (reg['matricula'] ?? '-').toString(),
        formatarNum(kmIni),
        formatarNum(kmFim),
        formatarNum(kmRod),
        litros > 0 ? litros.toStringAsFixed(2).replaceAll('.', ',') : '0,00',
        valor > 0 ? valor.toStringAsFixed(2).replaceAll('.', ',') : '0,00',
        avarias.isEmpty ? '-' : avarias,
        obs.isEmpty ? '-' : obs,
      ];

      for (int col = 0; col < valores.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = TextCellValue(valores[col]);
      }
      row++;
    }

    sheet.setColumnWidth(0, 14.0);
    sheet.setColumnWidth(1, 14.0);
    sheet.setColumnWidth(2, 14.0);
    sheet.setColumnWidth(3, 26.0);
    sheet.setColumnWidth(4, 15.0);
    sheet.setColumnWidth(5, 13.0);
    sheet.setColumnWidth(6, 13.0);
    sheet.setColumnWidth(7, 13.0);
    sheet.setColumnWidth(8, 12.0);
    sheet.setColumnWidth(9, 14.0);
    sheet.setColumnWidth(10, 30.0);
    sheet.setColumnWidth(11, 30.0);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Não foi possível codificar a planilha consolidada.');
    }

    final dir = await getTemporaryDirectory();
    final dataIso = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'Relatorio_Frota_$dataIso.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Compartilha o arquivo Excel (.xlsx) nativamente diretamente no WhatsApp / Apps do dispositivo
  static Future<void> compartilharExcel({
    required File arquivoExcel,
    required String textoMensagem,
  }) async {
    final xfile = XFile(
      arquivoExcel.path,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      name: arquivoExcel.uri.pathSegments.last,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [xfile],
        text: textoMensagem,
        subject: 'Relatório PMBA - Controle de Frota',
      ),
    );
  }
}
