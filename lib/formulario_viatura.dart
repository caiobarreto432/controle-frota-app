import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'services/session_manager.dart';
import 'services/excel_exporter.dart';

import 'config.dart';
import 'gerenciar_policiais.dart';
import 'historico.dart';
import 'login.dart';
import 'viaturas.dart';

class FormularioViatura extends StatefulWidget {
  const FormularioViatura({super.key});

  @override
  State<FormularioViatura> createState() => _FormularioViaturaState();
}

class _FormularioViaturaState extends State<FormularioViatura> {
  final TextEditingController prefixoController = TextEditingController();

  final TextEditingController placaController = TextEditingController();

  final TextEditingController kmInicialController = TextEditingController();

  final TextEditingController kmFinalController = TextEditingController();

  final TextEditingController litrosController = TextEditingController();

  final TextEditingController valorController = TextEditingController();

  final TextEditingController avariasController = TextEditingController();

  final TextEditingController observacoesController = TextEditingController();

  bool abasteceu = false;
  bool salvando = false;

  String nomePolicial = '';
  String matriculaPolicial = '';
  String perfil = 'POLICIAL';

  Map<String, dynamic>? viaturaSelecionada;

  bool checklistSaidaConcluido = false;
  Map<String, dynamic>? dadosChecklistSaida;

  bool checklistRetornoConcluido = false;
  Map<String, dynamic>? dadosChecklistRetorno;
  bool _restaurandoEstado = false;

  @override
  void initState() {
    super.initState();
    for (final ctrl in [
      kmFinalController,
      litrosController,
      valorController,
      avariasController,
      observacoesController,
    ]) {
      ctrl.addListener(_onCampoAlterado);
    }
    carregarUsuario();
    _restaurarEstadoPlantao();
  }

  void _onCampoAlterado() {
    if (_restaurandoEstado || viaturaSelecionada == null) return;
    _salvarEstadoPlantao();
  }

  Future<void> _salvarEstadoPlantao() async {
    if (viaturaSelecionada == null) return;
    await SessionManager.savePlantaoAtivo({
      'viatura_selecionada': viaturaSelecionada,
      'checklist_saida_concluido': checklistSaidaConcluido,
      'dados_checklist_saida': dadosChecklistSaida,
      'checklist_retorno_concluido': checklistRetornoConcluido,
      'dados_checklist_retorno': dadosChecklistRetorno,
      'km_final': kmFinalController.text,
      'abasteceu': abasteceu,
      'litros': litrosController.text,
      'valor': valorController.text,
      'avarias': avariasController.text,
      'observacoes': observacoesController.text,
    });
  }

  Future<void> _restaurarEstadoPlantao() async {
    final salvo = await SessionManager.getPlantaoAtivo();
    if (!mounted || salvo == null) return;

    final rawViatura = salvo['viatura_selecionada'];
    if (rawViatura is! Map) return;

    _restaurandoEstado = true;
    try {
      final viatura = Map<String, dynamic>.from(rawViatura);
      setState(() {
        viaturaSelecionada = viatura;
        checklistSaidaConcluido = salvo['checklist_saida_concluido'] == true;
        final rawSaida = salvo['dados_checklist_saida'];
        dadosChecklistSaida =
            rawSaida is Map ? Map<String, dynamic>.from(rawSaida) : null;

        checklistRetornoConcluido =
            salvo['checklist_retorno_concluido'] == true;
        final rawRetorno = salvo['dados_checklist_retorno'];
        dadosChecklistRetorno =
            rawRetorno is Map ? Map<String, dynamic>.from(rawRetorno) : null;

        prefixoController.text = viatura['prefixo']?.toString() ?? '';
        placaController.text = viatura['placa']?.toString() ?? '';
        kmInicialController.text = viatura['km_atual']?.toString() ?? '';
        kmFinalController.text = salvo['km_final']?.toString() ?? '';
        abasteceu = salvo['abasteceu'] == true;
        litrosController.text = salvo['litros']?.toString() ?? '';
        valorController.text = salvo['valor']?.toString() ?? '';
        avariasController.text = salvo['avarias']?.toString() ?? '';
        observacoesController.text = salvo['observacoes']?.toString() ?? '';
      });
      mostrarMensagem(
        'Plantão em andamento restaurado (${viatura['prefixo'] ?? '-'}).',
      );
    } finally {
      _restaurandoEstado = false;
    }
  }

  void _incorporarProblemasNasAvarias(
    Map<String, dynamic> resultadoChecklist,
    String etapa,
  ) {
    final status =
        resultadoChecklist['checklist_status']?.toString().toUpperCase() ?? '';
    if (status != 'PROBLEMA') return;

    final resumo =
        (resultadoChecklist['checklist_resumo_problemas']?.toString().trim() ??
                '')
            .isNotEmpty
            ? resultadoChecklist['checklist_resumo_problemas'].toString().trim()
            : (resultadoChecklist['checklist_observacao']?.toString().trim() ??
                '');

    if (resumo.isEmpty) return;

    final linhaNova = '[$etapa]: $resumo';
    final atual = avariasController.text.trim();
    if (atual.contains(linhaNova)) return;

    avariasController.text = atual.isEmpty ? linhaNova : '$atual\n$linhaNova';
  }

  Future<void> carregarUsuario() async {
    final nome = await SessionManager.getNome();
    final matricula = await SessionManager.getMatricula();
    final perfilSalvo = await SessionManager.getPerfil();

    if (!mounted) return;

    setState(() {
      nomePolicial = nome;
      matriculaPolicial = matricula;
      perfil = perfilSalvo.toUpperCase();
    });
  }

  String dataAtual() {
    final agora = DateTime.now();

    return '${agora.year}-'
        '${agora.month.toString().padLeft(2, '0')}-'
        '${agora.day.toString().padLeft(2, '0')}';
  }

  Future<void> logout() async {
    await SessionManager.clearSession();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> abrirViaturas() async {
    final scaffold = Scaffold.maybeOf(context);

    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();

      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    final resultado = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const ViaturasPage()),
    );

    if (!mounted) return;

    if (resultado == null) {
      return;
    }

    final viatura = Map<String, dynamic>.from(resultado);

    _restaurandoEstado = true;
    try {
      setState(() {
        viaturaSelecionada = viatura;

        checklistSaidaConcluido = viatura['checklist_status'] != null;
        dadosChecklistSaida = viatura;
        checklistRetornoConcluido = false;
        dadosChecklistRetorno = null;

        prefixoController.text = viatura['prefixo']?.toString() ?? '';

        placaController.text = viatura['placa']?.toString() ?? '';

        kmInicialController.text = viatura['km_atual']?.toString() ?? '';
      });

      _incorporarProblemasNasAvarias(viatura, 'SAÍDA');
    } finally {
      _restaurandoEstado = false;
    }

    await _salvarEstadoPlantao();

    mostrarMensagem('Checklist de Saída concluído. Viatura selecionada.');
  }

  Future<void> abrirGerenciarPoliciais() async {
    final scaffold = Scaffold.maybeOf(context);

    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();

      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GerenciarPoliciaisPage()));
  }

  Future<void> abrirHistorico() async {
    final scaffold = Scaffold.maybeOf(context);

    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();

      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HistoricoPage()));
  }

  Future<void> refazerChecklistSaida() async {
    final viatura = viaturaSelecionada;

    if (viatura == null) {
      mostrarMensagem('Nenhuma viatura selecionada.');
      return;
    }

    final resultado = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ChecklistViaturaPage(
          viatura: Map<String, dynamic>.from(viatura),
          tipoChecklist: 'SAIDA',
        ),
      ),
    );

    if (!mounted) return;

    if (resultado == null) {
      return;
    }

    final novaViatura = Map<String, dynamic>.from(resultado);

    _restaurandoEstado = true;
    try {
      setState(() {
        viaturaSelecionada = novaViatura;
        checklistSaidaConcluido = novaViatura['checklist_status'] != null;
        dadosChecklistSaida = novaViatura;

        prefixoController.text = novaViatura['prefixo']?.toString() ?? '';
        placaController.text = novaViatura['placa']?.toString() ?? '';
        kmInicialController.text = novaViatura['km_atual']?.toString() ?? '';
      });

      _incorporarProblemasNasAvarias(novaViatura, 'SAÍDA');
    } finally {
      _restaurandoEstado = false;
    }

    await _salvarEstadoPlantao();

    mostrarMensagem('Checklist de Saída atualizado com sucesso.');
  }

  Future<void> fazerChecklistRetorno() async {
    final viatura = viaturaSelecionada;

    if (viatura == null) {
      mostrarMensagem('Selecione primeiro uma viatura.');
      return;
    }

    final kmFinalTexto = kmFinalController.text.trim().replaceAll('.', '');
    final kmFinalNum = int.tryParse(kmFinalTexto);

    final resultado = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ChecklistViaturaPage(
          viatura: Map<String, dynamic>.from(viatura),
          tipoChecklist: 'RETORNO',
          kmReferencia: kmFinalNum,
        ),
      ),
    );

    if (!mounted) return;

    if (resultado == null) {
      return;
    }

    final dadosRetorno = Map<String, dynamic>.from(resultado);

    _restaurandoEstado = true;
    try {
      setState(() {
        checklistRetornoConcluido = true;
        dadosChecklistRetorno = dadosRetorno;
        if (dadosRetorno['checklist_km'] != null) {
          kmFinalController.text = dadosRetorno['checklist_km'].toString();
        }
      });

      _incorporarProblemasNasAvarias(dadosRetorno, 'DEVOLUÇÃO');
    } finally {
      _restaurandoEstado = false;
    }

    await _salvarEstadoPlantao();

    mostrarMensagem('Checklist de Devolução (Término de Serviço) concluído!');
  }

  Future<void> _confirmarCancelarSelecaoViatura() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar plantão atual?'),
        content: const Text(
          'Isso removerá a viatura selecionada e os dados preenchidos nesta tela.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('MANTER'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('DESCARTAR'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      limparFormulario();
      mostrarMensagem('Seleção de viatura cancelada.');
    }
  }

  Future<void> _compartilharArquivoExcelRegistro({
    required String prefixo,
    required String placa,
    required int kmInicial,
    required int kmFinal,
    required bool houveAbastecimento,
    required double litros,
    required double valor,
    required String avarias,
    required String observacoes,
    Map<String, dynamic>? viaturaSnap,
    Map<String, dynamic>? saidaSnap,
    Map<String, dynamic>? retornoSnap,
  }) async {
    try {
      final registroMap = {
        'prefixo_viatura': prefixo,
        'placa_viatura': placa,
        'nome_policial': nomePolicial,
        'matricula': matriculaPolicial,
        'data_servico': dataAtual(),
        'km_inicial': kmInicial,
        'km_final': kmFinal,
        'combustivel_inicial': litros,
        'combustivel_final': valor,
        'ocorrencias': avarias,
        'observacoes': observacoes,
      };

      final arquivoExcel = await ExcelExporter.gerarExcelRegistro(
        registro: registroMap,
        viatura: viaturaSnap ?? viaturaSelecionada,
        checklistSaida: saidaSnap ?? dadosChecklistSaida,
        checklistRetorno: retornoSnap ?? dadosChecklistRetorno,
      );

      final kmRodados = kmFinal >= kmInicial ? (kmFinal - kmInicial) : 0;
      final texto = '🚨 *PMBA - CONTROLE DE FROTA* 🚨\n'
          '📋 *REGISTRO DE USO DE VIATURA*\n\n'
          '🚗 *Viatura:* $prefixo (Placa: $placa)\n'
          '👮 *Policial:* $nomePolicial (Mat.: $matriculaPolicial)\n'
          '📅 *Data:* ${dataAtual()}\n'
          '🛣️ *KM Inicial:* $kmInicial km | *KM Final:* $kmFinal km ($kmRodados km rodados)\n'
          '⛽ *Abastecimento:* ${houveAbastecimento ? "Sim (${litros.toStringAsFixed(2).replaceAll('.', ',')} L - R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')})" : "Não"}\n\n'
          '📎 Segue em anexo a planilha Excel (.xlsx) oficial do registro gerada pelo aplicativo.';

      await ExcelExporter.compartilharExcel(
        arquivoExcel: arquivoExcel,
        textoMensagem: texto,
      );
    } catch (e) {
      mostrarMensagem('Erro ao gerar/compartilhar planilha Excel: $e');
    }
  }

  Future<void> _enviarRegistroWhatsAppComandante({
    required String prefixo,
    required String placa,
    required int kmInicial,
    required int kmFinal,
    required bool houveAbastecimento,
    required double litros,
    required double valor,
    required String avarias,
    required String observacoes,
    required String planilhaUrl,
  }) async {
    const numeroComandante = ApiConfig.numeroComandanteWhatsApp;
    final kmRodados = kmFinal >= kmInicial ? (kmFinal - kmInicial) : 0;

    final buffer = StringBuffer()
      ..writeln('🚨 *PMBA - CONTROLE DE FROTA* 🚨')
      ..writeln('📋 *REGISTRO DE USO DE VIATURA*')
      ..writeln()
      ..writeln('🚗 *Viatura:* $prefixo (Placa: $placa)')
      ..writeln('👮 *Policial:* $nomePolicial (Mat.: $matriculaPolicial)')
      ..writeln('📅 *Data:* ${dataAtual()}')
      ..writeln('🛣️ *KM Inicial:* $kmInicial km | *KM Final:* $kmFinal km ($kmRodados km rodados)')
      ..writeln(
        '⛽ *Abastecimento:* ${houveAbastecimento ? "Sim (${litros.toStringAsFixed(2).replaceAll('.', ',')} L - R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')})" : "Não"}',
      );

    if (avarias.isNotEmpty) {
      buffer.writeln('⚠️ *Avarias/Ocorrências:* $avarias');
    }
    if (observacoes.isNotEmpty) {
      buffer.writeln('📝 *Observações:* $observacoes');
    }

    if (planilhaUrl.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('📥 *Baixar Planilha Excel (.xlsx):* $planilhaUrl');
    }

    buffer
      ..writeln()
      ..write('📎 Relatório em Excel gerado pelo Sistema de Controle de Frota.');

    final texto = buffer.toString();

    final uriApp = Uri.parse(
      'whatsapp://send?phone=$numeroComandante&text=${Uri.encodeComponent(texto)}',
    );
    final uriWeb = Uri.parse(
      'https://wa.me/$numeroComandante?text=${Uri.encodeComponent(texto)}',
    );

    try {
      final abriuApp =
          await launchUrl(uriApp, mode: LaunchMode.externalApplication);
      if (!abriuApp) {
        await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      try {
        await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
      } catch (err) {
        debugPrint('Erro ao abrir WhatsApp: $err');
      }
    }
  }

  Future<void> _baixarPlanilhaExcel(String url) async {
    if (url.trim().isEmpty) {
      mostrarMensagem('Link da planilha não disponível.');
      return;
    }
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      mostrarMensagem('Não foi possível abrir o link da planilha Excel.');
    }
  }

  Future<void> salvarRegistro() async {
    if (salvando) return;

    final viatura = viaturaSelecionada;

    if (viatura == null) {
      mostrarMensagem('Selecione uma viatura antes de salvar.');
      return;
    }

    if (!checklistSaidaConcluido) {
      mostrarMensagem('Realize o Checklist de Saída antes de salvar o registro.');
      return;
    }

    if (!checklistRetornoConcluido) {
      // Abre dialogo orientando o policial a fazer o checklist de devolucao
      final fazerAgora = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.assignment_return, color: Colors.orange, size: 48),
          title: const Text('Checklist de Devolução Pendente'),
          content: const Text(
            'Ao terminar o serviço, é obrigatório realizar o Checklist de Devolução para registrar as condições de entrega da viatura.\n\nDeseja realizar a vistoria de devolução agora?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0033A0),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.check),
              label: const Text('FAZER CHECKLIST DE DEVOLUÇÃO'),
            ),
          ],
        ),
      );

      if (fazerAgora == true) {
        await fazerChecklistRetorno();
      }

      if (!checklistRetornoConcluido) {
        mostrarMensagem('O Checklist de Devolução deve ser concluído para encerrar o serviço.');
        return;
      }
    }

    final prefixo = prefixoController.text.trim();

    final placa = placaController.text.trim();

    final kmInicial =
        int.tryParse(kmInicialController.text.trim().replaceAll('.', ''));

    final kmFinal =
        int.tryParse(kmFinalController.text.trim().replaceAll('.', ''));

    if (prefixo.isEmpty) {
      mostrarMensagem('Prefixo da viatura não encontrada.');
      return;
    }

    if (placa.isEmpty) {
      mostrarMensagem('Placa da viatura não encontrada.');
      return;
    }

    if (kmInicial == null) {
      mostrarMensagem('KM Inicial inválido.');
      return;
    }

    if (kmFinal == null) {
      mostrarMensagem('KM Final inválido.');
      return;
    }
    if (kmFinal < kmInicial) {
      mostrarMensagem('O KM final não pode ser menor que o KM inicial.');
      return;
    }

    if (abasteceu && litrosController.text.trim().isEmpty) {
      mostrarMensagem('Informe os litros abastecidos.');
      return;
    }

    if (abasteceu && valorController.text.trim().isEmpty) {
      mostrarMensagem('Informe o valor do abastecimento.');
      return;
    }

    final viaturaId = viatura['id']?.toString();

    if (viaturaId == null || viaturaId.isEmpty) {
      mostrarMensagem('ID da viatura não encontrada.');
      return;
    }

    final litrosVal = abasteceu
        ? double.tryParse(litrosController.text.trim().replaceAll(',', '.')) ??
            0
        : 0.0;
    final valorVal = abasteceu
        ? double.tryParse(valorController.text.trim().replaceAll(',', '.')) ?? 0
        : 0.0;
    final avariasTexto = avariasController.text.trim();
    final obsTexto = observacoesController.text.trim();
    final houveAbast = abasteceu;

    setState(() {
      salvando = true;
    });

    try {
      final dados = {
        'viatura_id': viaturaId,
        'nome_policial': nomePolicial,
        'matricula': matriculaPolicial,
        'data_servico': dataAtual(),
        'prefixo_viatura': prefixo,
        'placa_viatura': placa,
        'km_inicial': kmInicial,
        'km_final': kmFinal,
        'combustivel_inicial': litrosVal,
        'combustivel_final': valorVal,
        'ocorrencias': avariasTexto,
        'observacoes': obsTexto,
      };

      final headers = await SessionManager.getAuthHeaders();

      final resposta = await http
          .post(
            ApiConfig.salvarRegistroUri,
            headers: headers,
            body: jsonEncode(dados),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        String planilhaUrl = '';
        try {
          final dadosResposta = jsonDecode(resposta.body);
          final regMap = dadosResposta['registro'] ?? {};
          final regId = regMap['id']?.toString() ?? '';
          planilhaUrl = regMap['planilha_url']?.toString() ??
              (regId.isNotEmpty ? ApiConfig.registroExcelUrl(regId) : '');
        } catch (_) {}

        if (planilhaUrl.isEmpty &&
            viatura['checklist_planilha_url'] != null &&
            viatura['checklist_planilha_url'].toString().isNotEmpty) {
          planilhaUrl = viatura['checklist_planilha_url'].toString();
        }

        final viaturaSnapshot = viaturaSelecionada != null
            ? Map<String, dynamic>.from(viaturaSelecionada!)
            : null;
        final saidaSnapshot = dadosChecklistSaida != null
            ? Map<String, dynamic>.from(dadosChecklistSaida!)
            : null;
        final retornoSnapshot = dadosChecklistRetorno != null
            ? Map<String, dynamic>.from(dadosChecklistRetorno!)
            : null;

        setState(() {
          salvando = false;
        });

        limparFormulario();

        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            title: const Text('Registro da Viatura Salvo!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'A planilha Excel (.xlsx) do registro da viatura foi gerada com sucesso!',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.table_chart, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Viatura: $prefixo ($placa)\n'
                          'KM: $kmInicial km → $kmFinal km\n'
                          'Policial: $nomePolicial',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Enviar o registro em Excel agora para o WhatsApp do Comandante (+55 71 99988-1574)?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsOverflowButtonSpacing: 8,
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    await _compartilharArquivoExcelRegistro(
                      prefixo: prefixo,
                      placa: placa,
                      kmInicial: kmInicial,
                      kmFinal: kmFinal,
                      houveAbastecimento: houveAbast,
                      litros: litrosVal,
                      valor: valorVal,
                      avarias: avariasTexto,
                      observacoes: obsTexto,
                      viaturaSnap: viaturaSnapshot,
                      saidaSnap: saidaSnapshot,
                      retornoSnap: retornoSnapshot,
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('ENVIAR ARQUIVO EXCEL NO WHATSAPP (.XLSX)'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogCtx).pop();
                    await _enviarRegistroWhatsAppComandante(
                      prefixo: prefixo,
                      placa: placa,
                      kmInicial: kmInicial,
                      kmFinal: kmFinal,
                      houveAbastecimento: houveAbast,
                      litros: litrosVal,
                      valor: valorVal,
                      avarias: avariasTexto,
                      observacoes: obsTexto,
                      planilhaUrl: planilhaUrl,
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('ENVIAR MENSAGEM COM LINK'),
                ),
              ),
              if (planilhaUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _baixarPlanilhaExcel(planilhaUrl),
                    icon: const Icon(Icons.download),
                    label: const Text('BAIXAR VIA NAVEGADOR'),
                  ),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('Concluir sem enviar'),
              ),
            ],
          ),
        );
      } else {
        String mensagem = 'Erro ao salvar o registro.';

        try {
          final dadosResposta = jsonDecode(resposta.body);

          mensagem = dadosResposta['mensagem']?.toString() ?? mensagem;
        } catch (_) {}

        mostrarMensagem(
          '$mensagem\n'
          'Código: ${resposta.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      debugPrint('ERRO SALVAR REGISTRO: $e');

      mostrarMensagem('Erro de conexão com o servidor.');
    } finally {
      if (mounted) {
        setState(() {
          salvando = false;
        });
      }
    }
  }

  void limparFormulario() {
    _restaurandoEstado = true;
    try {
      prefixoController.clear();
      placaController.clear();
      kmInicialController.clear();
      kmFinalController.clear();
      litrosController.clear();
      valorController.clear();
      avariasController.clear();
      observacoesController.clear();

      if (mounted) {
        setState(() {
          abasteceu = false;
          viaturaSelecionada = null;
          checklistSaidaConcluido = false;
          dadosChecklistSaida = null;
          checklistRetornoConcluido = false;
          dadosChecklistRetorno = null;
        });
      }
    } finally {
      _restaurandoEstado = false;
    }

    SessionManager.clearPlantaoAtivo();
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  void dispose() {
    prefixoController.dispose();
    placaController.dispose();
    kmInicialController.dispose();
    kmFinalController.dispose();
    litrosController.dispose();
    valorController.dispose();
    avariasController.dispose();
    observacoesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final administrador = perfil == 'ADMIN';

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                nomePolicial.isEmpty ? 'Usuário' : nomePolicial,
              ),
              accountEmail: Text(
                'Matrícula: '
                '$matriculaPolicial\n'
                'Perfil: $perfil',
              ),
            ),

            ListTile(
              leading: const Icon(Icons.directions_car),
              title: const Text('Viaturas'),
              subtitle: const Text('Selecionar viatura'),
              onTap: abrirViaturas,
            ),

            if (administrador)
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Gerenciar Policiais'),
                onTap: abrirGerenciarPoliciais,
              ),

            ListTile(
              leading: const Icon(Icons.history),
              title: Text(administrador ? 'Histórico Geral' : 'Meus Registros'),
              onTap: abrirHistorico,
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: logout,
            ),
          ],
        ),
      ),

      appBar: AppBar(
        title: const Text('Controle de Viaturas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: logout,
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person, size: 40),
                title: Text(
                  nomePolicial.isEmpty ? 'Carregando...' : nomePolicial,
                ),
                subtitle: Text(
                  'Matrícula: '
                  '$matriculaPolicial\n'
                  'Perfil: $perfil',
                ),
              ),
            ),

            const SizedBox(height: 18),

Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    viaturaSelecionada == null
                        ? Icons.directions_car_outlined
                        : viaturaSelecionada!['tipo']
                                  ?.toString()
                                  .toUpperCase() ==
                              'MOTO'
                        ? Icons.two_wheeler
                        : Icons.directions_car,
                  ),
                ),
                title: Text(
                  viaturaSelecionada == null
                      ? 'Nenhuma viatura selecionada'
                      : viaturaSelecionada!['prefixo']?.toString() ?? '-',
                ),
                subtitle: Text(
                  viaturaSelecionada == null
                      ? 'Toque para selecionar viatura e realizar a vistoria de saída.'
                      : '${viaturaSelecionada!['placa'] ?? '-'}\n'
                            'KM inicial: ${viaturaSelecionada!['km_atual'] ?? 0}\n'
                            'Vistoria de Saída: ${checklistSaidaConcluido ? "✅ Concluída" : "⚠️ Pendente"}',
                ),
                trailing: viaturaSelecionada == null
                    ? const Icon(Icons.arrow_forward)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            checklistSaidaConcluido
                                ? Icons.check_circle
                                : Icons.warning_amber,
                            color: checklistSaidaConcluido
                                ? Colors.green
                                : Colors.orange,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Cancelar seleção de viatura',
                            onPressed: salvando
                                ? null
                                : _confirmarCancelarSelecaoViatura,
                          ),
                        ],
                      ),
                onTap: abrirViaturas,
              ),
            ),

            if (viaturaSelecionada != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: salvando ? null : refazerChecklistSaida,
                      icon: const Icon(Icons.checklist),
                      label: const Text('REFAZER CHECKLIST DE SAÍDA'),
                    ),
                  ),
                  if (checklistSaidaConcluido) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: salvando
                            ? null
                            : () => _compartilharArquivoExcelRegistro(
                                  prefixo: prefixoController.text.trim(),
                                  placa: placaController.text.trim(),
                                  kmInicial: int.tryParse(
                                        kmInicialController.text
                                            .trim()
                                            .replaceAll('.', ''),
                                      ) ??
                                      0,
                                  kmFinal: int.tryParse(
                                        kmFinalController.text
                                            .trim()
                                            .replaceAll('.', ''),
                                      ) ??
                                      (int.tryParse(
                                            kmInicialController.text
                                                .trim()
                                                .replaceAll('.', ''),
                                          ) ??
                                          0),
                                  houveAbastecimento: abasteceu,
                                  litros: double.tryParse(
                                        litrosController.text
                                            .trim()
                                            .replaceAll(',', '.'),
                                      ) ??
                                      0,
                                  valor: double.tryParse(
                                        valorController.text
                                            .trim()
                                            .replaceAll(',', '.'),
                                      ) ??
                                      0,
                                  avarias: avariasController.text.trim(),
                                  observacoes:
                                      observacoesController.text.trim(),
                                ),
                        icon: const Icon(Icons.table_chart, size: 18),
                        label: const Text('GERAR/ENVIAR EXCEL'),
                      ),
                    ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 18),

            TextFormField(
              initialValue: dataAtual(),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Data do Serviço',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            campo(
              prefixoController,
              'Prefixo da Viatura',
              somenteLeitura: viaturaSelecionada != null,
            ),

            campo(
              placaController,
              'Placa da Viatura',
              somenteLeitura: viaturaSelecionada != null,
            ),

            campo(
              kmInicialController,
              'KM Inicial (Assunção)',
              somenteLeitura: viaturaSelecionada != null,
              teclado: TextInputType.number,
            ),

            campo(
              kmFinalController,
              'KM Final (Devolução)',
              teclado: TextInputType.number,
            ),

            Card(
              child: SwitchListTile(
                title: const Text('Abasteceu?'),
                subtitle: Text(abasteceu ? 'Sim' : 'Não'),
                value: abasteceu,
                onChanged: salvando
                    ? null
                    : (valor) {
                        setState(() {
                          abasteceu = valor;
                        });
                        _salvarEstadoPlantao();
                      },
              ),
            ),

            if (abasteceu) ...[
              campo(
                litrosController,
                'Litros',
                teclado: const TextInputType.numberWithOptions(decimal: true),
              ),

              campo(
                valorController,
                'Valor do Abastecimento',
                teclado: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],

            campo(avariasController, 'Avarias / Danos constatados no serviço', linhas: 4),

            campo(observacoesController, 'Observações Gerais', linhas: 4),

            const SizedBox(height: 16),

            // SECAO DEDICADA: CHECKLIST DE DEVOLUCAO (AO TERMINAR SERVICO)
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: checklistRetornoConcluido ? Colors.green : const Color(0xFFC3B091),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          checklistRetornoConcluido ? Icons.check_circle : Icons.assignment_return,
                          color: checklistRetornoConcluido ? Colors.green : const Color(0xFFC3B091),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            checklistRetornoConcluido
                                ? 'Checklist de Devolução: CONCLUÍDO ✅'
                                : 'Checklist de Devolução (Término de Serviço)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      checklistRetornoConcluido
                          ? 'Vistoria de entrega finalizada. Status: ${dadosChecklistRetorno?['checklist_status'] ?? "OK"} • KM Final: ${kmFinalController.text.trim()} km'
                          : 'Inspecione o estado da viatura ao devolver (pneus, lataria, limpeza, equipamentos) antes de salvar o encerramento do serviço.',
                      style: TextStyle(
                        fontSize: 13,
                        color: checklistRetornoConcluido ? Colors.white70 : Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: checklistRetornoConcluido
                              ? Colors.blueGrey
                              : const Color(0xFF0033A0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: (salvando || viaturaSelecionada == null)
                            ? null
                            : fazerChecklistRetorno,
                        icon: Icon(
                          checklistRetornoConcluido ? Icons.refresh : Icons.assignment_turned_in,
                        ),
                        label: Text(
                          checklistRetornoConcluido
                              ? 'REFAZER CHECKLIST DE DEVOLUÇÃO'
                              : 'REALIZAR CHECKLIST DE DEVOLUÇÃO',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (!checklistSaidaConcluido)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Selecione a viatura e conclua a vistoria de saída.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else if (!checklistRetornoConcluido)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lembre-se: realize o Checklist de Devolução para finalizar o plantão.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: salvando ? null : salvarRegistro,
                icon: salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  salvando
                      ? 'SALVANDO E GERANDO EXCEL...'
                      : 'SALVAR REGISTRO E GERAR EXCEL',
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget campo(
    TextEditingController controller,
    String label, {
    bool somenteLeitura = false,
    TextInputType? teclado,
    int? linhas,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: !salvando,
        readOnly: somenteLeitura,
        keyboardType: teclado,
        maxLines: linhas ?? 1,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
