import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'services/session_manager.dart';
import 'services/excel_exporter.dart';

import 'config.dart';
import 'models/registro_model.dart';

class HistoricoPage extends StatefulWidget {
  const HistoricoPage({super.key});

  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  List<RegistroServicoModel> registros = [];

  bool carregando = true;

  String erro = '';

  String matriculaUsuario = '';

  String perfilUsuario = 'POLICIAL';

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';
  String _filtroPeriodo = 'TODOS';
  bool _exportandoConsolidado = false;

  @override
  void initState() {
    super.initState();
    inicializar();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  List<RegistroServicoModel> get registrosFiltrados {
    final agora = DateTime.now();
    final termo = _termoBusca.trim().toLowerCase();

    return registros.where((r) {
      if (_filtroPeriodo != 'TODOS') {
        final ref = (r.dataServico ?? r.criadoEm)?.toLocal();
        if (ref == null) return false;

        if (_filtroPeriodo == 'HOJE') {
          if (ref.year != agora.year ||
              ref.month != agora.month ||
              ref.day != agora.day) {
            return false;
          }
        } else if (_filtroPeriodo == '7DIAS') {
          final limite = DateTime(agora.year, agora.month, agora.day)
              .subtract(const Duration(days: 6));
          if (ref.isBefore(limite)) {
            return false;
          }
        } else if (_filtroPeriodo == 'MES') {
          if (ref.year != agora.year || ref.month != agora.month) {
            return false;
          }
        }
      }

      if (termo.isNotEmpty) {
        final batePrefixo = r.prefixoViatura.toLowerCase().contains(termo);
        final batePlaca = r.placaViatura.toLowerCase().contains(termo);
        final bateNome = r.nomePolicial.toLowerCase().contains(termo);
        final bateMatricula = r.matricula.toLowerCase().contains(termo);
        if (!batePrefixo && !batePlaca && !bateNome && !bateMatricula) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String get _descricaoFiltroAtual {
    String base;
    switch (_filtroPeriodo) {
      case 'HOJE':
        base = 'Hoje';
        break;
      case '7DIAS':
        base = 'Últimos 7 dias';
        break;
      case 'MES':
        base = 'Este mês';
        break;
      default:
        base = 'Todos os registros';
    }
    final termo = _termoBusca.trim();
    return termo.isEmpty ? base : '$base (Busca: "$termo")';
  }

  Future<void> _exportarRelatorioConsolidado() async {
    final filtrados = registrosFiltrados;
    if (filtrados.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum registro encontrado no filtro atual para exportar.'),
        ),
      );
      return;
    }

    setState(() {
      _exportandoConsolidado = true;
    });

    try {
      final arquivo = await ExcelExporter.gerarExcelHistoricoConsolidado(
        registros: filtrados.map((r) => r.toMap()).toList(),
        filtroDescricao: _descricaoFiltroAtual,
      );

      final kmTotal = filtrados.fold<double>(0, (acc, r) => acc + r.kmRodado);
      final texto = '🚨 *PMBA - CONTROLE DE FROTA* 🚨\n'
          '📊 *RELATÓRIO CONSOLIDADO DE SERVIÇOS*\n\n'
          '🔎 *Filtro:* $_descricaoFiltroAtual\n'
          '📋 *Registros:* ${filtrados.length}\n'
          '🛣️ *Total KM Rodado:* ${formatarNumero(kmTotal)} km\n\n'
          '📎 Segue em anexo a planilha Excel (.xlsx) consolidada gerada pelo aplicativo.';

      await ExcelExporter.compartilharExcel(
        arquivoExcel: arquivo,
        textoMensagem: texto,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar relatório consolidado: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportandoConsolidado = false;
        });
      }
    }
  }

  Future<void> inicializar() async {
    final matricula = await SessionManager.getMatricula();
    final perfil = await SessionManager.getPerfil();

    if (!mounted) return;

    setState(() {
      matriculaUsuario = matricula;
      perfilUsuario = perfil.toUpperCase();
    });

    await carregarRegistros();
  }

  Future<void> carregarRegistros() async {
    if (!mounted) return;

    if (matriculaUsuario.isEmpty) {
      setState(() {
        carregando = false;
        erro = 'Matrícula do usuário não encontrada.';
      });
      return;
    }

    setState(() {
      carregando = true;
      erro = '';
    });

    try {
      final headers = await SessionManager.getAuthHeaders();

      final resposta = await http
          .get(
            ApiConfig.registrosUri,
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);

        if (dados is List) {
          setState(() {
            registros = dados
                .whereType<Map>()
                .map((item) => RegistroServicoModel.fromMap(
                      Map<String, dynamic>.from(item),
                    ))
                .toList();
            carregando = false;
            erro = '';
          });
        } else {
          setState(() {
            registros = [];
            carregando = false;
            erro = 'O servidor retornou um formato inválido.';
          });
        }

        return;
      }

      String mensagem = 'Erro ao carregar os registros.';

      try {
        final dados = jsonDecode(resposta.body);

        mensagem = dados['mensagem']?.toString() ?? mensagem;
      } catch (_) {}

      setState(() {
        carregando = false;
        erro =
            '$mensagem\n'
            'Código: ${resposta.statusCode}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
        erro = 'Não foi possível conectar ao servidor.';
      });
    }
  }

  String formatarData(dynamic valor) {
    if (valor == null) {
      return '-';
    }

    if (valor is DateTime) {
      final data = valor.toLocal();
      return '${data.day.toString().padLeft(2, '0')}/'
          '${data.month.toString().padLeft(2, '0')}/'
          '${data.year} '
          '${data.hour.toString().padLeft(2, '0')}:'
          '${data.minute.toString().padLeft(2, '0')}';
    }

    final texto = valor.toString();

    if (texto.isEmpty) {
      return '-';
    }

    try {
      final data = DateTime.parse(texto).toLocal();

      return '${data.day.toString().padLeft(2, '0')}/'
          '${data.month.toString().padLeft(2, '0')}/'
          '${data.year} '
          '${data.hour.toString().padLeft(2, '0')}:'
          '${data.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return texto;
    }
  }

  String texto(dynamic valor) {
    if (valor == null) {
      return '-';
    }

    final resultado = valor.toString().trim();

    return resultado.isEmpty ? '-' : resultado;
  }

  String formatarNumero(dynamic valor) {
    if (valor == null) {
      return '0';
    }

    final numero = double.tryParse(valor.toString().replaceAll(',', '.'));

    if (numero == null) {
      return texto(valor);
    }

    if (numero == numero.roundToDouble()) {
      return numero.toInt().toString();
    }

    return numero.toStringAsFixed(2).replaceAll('.', ',');
  }

  String formatarLitros(dynamic valor) {
    if (valor == null) {
      return '0,00 L';
    }

    final numero = double.tryParse(valor.toString().replaceAll(',', '.'));

    if (numero == null) {
      return '${texto(valor)} L';
    }

    return '${numero.toStringAsFixed(2).replaceAll('.', ',')} L';
  }

  String formatarReais(dynamic valor) {
    if (valor == null) {
      return 'R\$ 0,00';
    }

    final numero = double.tryParse(valor.toString().replaceAll(',', '.'));

    if (numero == null) {
      return 'R\$ ${texto(valor)}';
    }

    return 'R\$ ${numero.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  Future<void> _compartilharArquivoExcelHistorico(
      RegistroServicoModel registro) async {
    try {
      final arquivoExcel = await ExcelExporter.gerarExcelRegistro(
        registro: registro.toMap(),
      );

      final buffer = StringBuffer()
        ..writeln('🚨 *PMBA - CONTROLE DE FROTA* 🚨')
        ..writeln('📋 *REGISTRO DE USO DE VIATURA*')
        ..writeln()
        ..writeln(
          '🚗 *Viatura:* ${registro.prefixoViatura} (Placa: ${registro.placaViatura})',
        )
        ..writeln(
          '👮 *Policial:* ${registro.nomePolicial} (Mat.: ${registro.matricula})',
        )
        ..writeln('📅 *Data:* ${formatarData(registro.dataServico)}')
        ..writeln(
          '🛣️ *KM Inicial:* ${formatarNumero(registro.kmInicial)} km | *KM Final:* ${formatarNumero(registro.kmFinal)} km (${formatarNumero(registro.kmRodado)} km rodados)',
        )
        ..writeln(
          '⛽ *Abastecimento:* ${registro.houveAbastecimento ? "Sim (${formatarLitros(registro.litrosAbastecidos)} - ${formatarReais(registro.valorAbastecimento)})" : "Não"}',
        );

      if (registro.ocorrencias.isNotEmpty) {
        buffer.writeln('⚠️ *Avarias/Ocorrências:* ${registro.ocorrencias}');
      }
      if (registro.observacoes.isNotEmpty) {
        buffer.writeln('📝 *Observações:* ${registro.observacoes}');
      }

      buffer
        ..writeln()
        ..write(
          '📎 Segue em anexo a planilha Excel (.xlsx) oficial do registro gerada pelo aplicativo.',
        );

      await ExcelExporter.compartilharExcel(
        arquivoExcel: arquivoExcel,
        textoMensagem: buffer.toString(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao gerar/compartilhar planilha Excel: $e'),
        ),
      );
    }
  }

  Future<void> _enviarRegistroWhatsApp(RegistroServicoModel registro) async {
    const numeroComandante = ApiConfig.numeroComandanteWhatsApp;
    final urlPlanilha = (registro.planilhaUrl != null &&
            registro.planilhaUrl!.trim().isNotEmpty)
        ? registro.planilhaUrl!
        : ApiConfig.registroExcelUrl(registro.id.toString());

    final buffer = StringBuffer()
      ..writeln('🚨 *PMBA - CONTROLE DE FROTA* 🚨')
      ..writeln('📋 *REGISTRO DE USO DE VIATURA*')
      ..writeln()
      ..writeln(
        '🚗 *Viatura:* ${registro.prefixoViatura} (Placa: ${registro.placaViatura})',
      )
      ..writeln('👮 *Policial:* ${registro.nomePolicial} (Mat.: ${registro.matricula})')
      ..writeln('📅 *Data:* ${formatarData(registro.dataServico)}')
      ..writeln(
        '🛣️ *KM Inicial:* ${formatarNumero(registro.kmInicial)} km | *KM Final:* ${formatarNumero(registro.kmFinal)} km (${formatarNumero(registro.kmRodado)} km rodados)',
      )
      ..writeln(
        '⛽ *Abastecimento:* ${registro.houveAbastecimento ? "Sim (${formatarLitros(registro.litrosAbastecidos)} - ${formatarReais(registro.valorAbastecimento)})" : "Não"}',
      );

    if (registro.ocorrencias.isNotEmpty) {
      buffer.writeln('⚠️ *Avarias/Ocorrências:* ${registro.ocorrencias}');
    }
    if (registro.observacoes.isNotEmpty) {
      buffer.writeln('📝 *Observações:* ${registro.observacoes}');
    }

    buffer
      ..writeln()
      ..writeln('📥 *Baixar Planilha Excel (.xlsx):* $urlPlanilha')
      ..writeln()
      ..write('📎 Relatório em Excel gerado pelo Sistema de Controle de Frota.');

    final textoMensagem = buffer.toString();

    final uriApp = Uri.parse(
      'whatsapp://send?phone=$numeroComandante&text=${Uri.encodeComponent(textoMensagem)}',
    );
    final uriWeb = Uri.parse(
      'https://wa.me/$numeroComandante?text=${Uri.encodeComponent(textoMensagem)}',
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

  Widget linha(String titulo, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(texto(valor))),
        ],
      ),
    );
  }

  Widget linhaAbastecimento(RegistroServicoModel registro) {
    if (!registro.houveAbastecimento) {
      return linha('Abastecimento', 'Não');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        linha('Abastecimento', 'Sim'),
        linha('Litros abastecidos', formatarLitros(registro.litrosAbastecidos)),
        linha('Valor pago', formatarReais(registro.valorAbastecimento)),
      ],
    );
  }

  Widget construirRegistro(RegistroServicoModel registro) {
    final titulo = registro.tituloViatura;
    final nome = registro.nomePolicial;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.directions_car)),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$nome • '
          '${formatarData(registro.dataServico)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),

          linha('Policial', registro.nomePolicial),

          linha('Matrícula', registro.matricula),

          linha('Data', formatarData(registro.dataServico)),

          linha('Prefixo', registro.prefixoViatura),

          linha('Placa', registro.placaViatura),

          linha('KM inicial', formatarNumero(registro.kmInicial)),

          linha('KM final', formatarNumero(registro.kmFinal)),

          const SizedBox(height: 4),

          linhaAbastecimento(registro),

          linha('Avarias', registro.ocorrencias),

          linha('Observações', registro.observacoes),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _compartilharArquivoExcelHistorico(registro),
              icon: const Icon(Icons.share),
              label: const Text('ENVIAR ARQUIVO EXCEL NO WHATSAPP (.XLSX)'),
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _enviarRegistroWhatsApp(registro),
              icon: const Icon(Icons.send),
              label: const Text('ENVIAR MENSAGEM COM LINK NO WHATSAPP'),
            ),
          ),
        ],
      ),
    );
  }

  Widget construirCorpo() {
    if (carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (erro.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: carregarRegistros,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  erro,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (registros.isEmpty) {
      return RefreshIndicator(
        onRefresh: carregarRegistros,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 220),
            Center(
              child: Text(
                perfilUsuario == 'ADMIN'
                    ? 'Nenhum registro encontrado.'
                    : 'Você ainda não possui registros.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      );
    }

    final filtrados = registrosFiltrados;
    final kmTotalFiltrado =
        filtrados.fold<double>(0, (acc, r) => acc + r.kmRodado);

    Widget chipPeriodo(String valor, String rotulo) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(rotulo),
          selected: _filtroPeriodo == valor,
          onSelected: (_) {
            setState(() {
              _filtroPeriodo = valor;
            });
          },
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            children: [
              TextField(
                controller: _buscaController,
                onChanged: (valor) {
                  setState(() {
                    _termoBusca = valor;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar por prefixo, placa, policial ou matrícula...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _termoBusca.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _buscaController.clear();
                            setState(() {
                              _termoBusca = '';
                            });
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    chipPeriodo('TODOS', 'Todos'),
                    chipPeriodo('HOJE', 'Hoje'),
                    chipPeriodo('7DIAS', '7 dias'),
                    chipPeriodo('MES', 'Este mês'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${filtrados.length} registro(s) • ${formatarNumero(kmTotalFiltrado)} km rodados',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: (filtrados.isEmpty || _exportandoConsolidado)
                          ? null
                          : _exportarRelatorioConsolidado,
                      icon: _exportandoConsolidado
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.table_view, size: 18),
                      label: const Text('EXPORTAR EXCEL'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtrados.isEmpty
              ? RefreshIndicator(
                  onRefresh: carregarRegistros,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 140),
                      Center(
                        child: Text(
                          'Nenhum registro encontrado para este filtro.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: carregarRegistros,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: filtrados.length,
                    itemBuilder: (context, index) {
                      return construirRegistro(filtrados[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          perfilUsuario == 'ADMIN' ? 'Histórico Geral' : 'Meus Registros',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view),
            tooltip: 'Exportar Relatório Consolidado (.xlsx)',
            onPressed: (carregando ||
                    _exportandoConsolidado ||
                    registrosFiltrados.isEmpty)
                ? null
                : _exportarRelatorioConsolidado,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: carregando ? null : carregarRegistros,
          ),
        ],
      ),
      body: construirCorpo(),
    );
  }
}
