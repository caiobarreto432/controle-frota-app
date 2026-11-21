import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'config.dart';
import 'models/checklist_model.dart';
import 'services/excel_exporter.dart';
import 'services/session_manager.dart';
import 'widgets/seletor_fotos.dart';

/* =========================================================
   VIATURAS
========================================================= */

class ViaturasPage extends StatefulWidget {
  const ViaturasPage({super.key});

  @override
  State<ViaturasPage> createState() => _ViaturasPageState();
}

class _ViaturasPageState extends State<ViaturasPage> {
  List<Map<String, dynamic>> viaturas = [];

  bool carregando = true;

  String matricula = '';
  String perfil = 'POLICIAL';

  @override
  void initState() {
    super.initState();
    iniciar();
  }

  Future<void> iniciar() async {
    matricula = await SessionManager.getMatricula();
    perfil = await SessionManager.getPerfil();

    await carregarViaturas();
  }

  Future<void> carregarViaturas() async {
    if (!mounted) return;

    setState(() {
      carregando = true;
    });

    try {
      final headers = await SessionManager.getAuthHeaders();
      final response = await http
          .get(
            ApiConfig.viaturasUri,
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          viaturas = data
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        } else {
          viaturas = [];
        }
      }

      setState(() {
        carregando = false;
      });

      if (response.statusCode != 200) {
        mostrarMensagem(
          'Erro ao carregar viaturas.\n'
          'Código: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      mostrarMensagem('Não foi possível conectar ao servidor.');

      debugPrint('ERRO VIATURAS: $e');
    }
  }

  Future<void> selecionarViatura(Map<String, dynamic> viatura) async {
    final ativo = viatura['ativo'] == true;

    if (!ativo) {
      mostrarMensagem('Esta viatura está desativada.');
      return;
    }

    final resultado = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) =>
            ChecklistViaturaPage(viatura: Map<String, dynamic>.from(viatura)),
      ),
    );

    if (!mounted) return;

    if (resultado != null) {
      /*
       * O checklist terminou.
       *
       * Retorna a viatura para o formulário.
       */
      Navigator.of(context).pop(resultado);
    }
  }

  Future<void> abrirUltimasVistorias(Map<String, dynamic> viatura) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoricoChecklistsViaturaPage(
          viatura: Map<String, dynamic>.from(viatura),
        ),
      ),
    );
  }

  Future<void> abrirCadastro() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CadastroViaturaPage()),
    );

    if (!mounted) return;

    if (resultado == true) {
      await carregarViaturas();
    }
  }

  Future<void> abrirEdicao(Map<String, dynamic> viatura) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CadastroViaturaPage(viatura: Map<String, dynamic>.from(viatura)),
      ),
    );

    if (!mounted) return;

    if (resultado == true) {
      await carregarViaturas();
    }
  }

  Future<void> alterarStatus(Map<String, dynamic> viatura) async {
    final id = viatura['id']?.toString();

    if (id == null || id.isEmpty) {
      mostrarMensagem('ID da viatura não encontrado.');
      return;
    }

    final ativoAtual = viatura['ativo'] == true;

    try {
      final headers = await SessionManager.getAuthHeaders();
      final response = await http
          .put(
            ApiConfig.viaturaStatusUri(id),
            headers: headers,
            body: jsonEncode({'ativo': !ativoAtual}),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        mostrarMensagem(
          ativoAtual ? 'Viatura desativada.' : 'Viatura ativada.',
        );

        await carregarViaturas();
      } else {
        mostrarMensagem(
          'Erro ao alterar status.\n'
          'Código: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem('Erro de conexão com o servidor.');

      debugPrint('ERRO STATUS VIATURA: $e');
    }
  }

  String tipoTexto(Map<String, dynamic> viatura) {
    return (viatura['tipo']?.toString() ?? 'CARRO').toUpperCase();
  }

  IconData tipoIcone(String tipo) {
    if (tipo == 'MOTO') {
      return Icons.two_wheeler;
    }

    return Icons.directions_car;
  }

  String formatarKm(dynamic valor) {
    final numero = int.tryParse(valor?.toString() ?? '') ?? 0;

    return numero.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  Color corManutencao(String situacao) {
    switch (situacao) {
      case 'VENCIDA':
        return Colors.red;

      case 'PROXIMA':
        return Colors.orange;

      default:
        return Colors.green;
    }
  }

  String textoManutencao(Map<String, dynamic> viatura) {
    final situacao = (viatura['manutencao']?.toString() ?? 'NORMAL')
        .toUpperCase();

    final restante =
        int.tryParse(viatura['km_restante']?.toString() ?? '') ?? 0;

    if (situacao == 'VENCIDA') {
      return 'Manutenção vencida em '
          '${formatarKm(restante.abs())} km';
    }

    if (situacao == 'PROXIMA') {
      return 'Faltam '
          '${formatarKm(restante)} km';
    }

    return 'Manutenção em dia';
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = perfil == 'ADMIN';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Viaturas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: carregando ? null : carregarViaturas,
          ),
        ],
      ),

      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: abrirCadastro,
              icon: const Icon(Icons.add),
              label: const Text('VIATURA'),
            )
          : null,

      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : viaturas.isEmpty
          ? RefreshIndicator(
              onRefresh: carregarViaturas,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 250),
                  Center(child: Text('Nenhuma viatura cadastrada.')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: carregarViaturas,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: viaturas.length,
                itemBuilder: (context, index) {
                  final viatura = viaturas[index];

                  final tipo = tipoTexto(viatura);

                  final prefixo = viatura['prefixo']?.toString() ?? '-';

                  final placa = viatura['placa']?.toString() ?? '-';

                  final marca = viatura['marca']?.toString() ?? '';

                  final modelo = viatura['modelo']?.toString() ?? '';

                  final ativo = viatura['ativo'] == true;

                  final manutencao =
                      (viatura['manutencao']?.toString() ?? 'NORMAL')
                          .toUpperCase();

                  final cor = corManutencao(manutencao);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: ativo
                          ? () {
                              selecionarViatura(viatura);
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(child: Icon(tipoIcone(tipo))),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prefixo,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text('$tipo • $placa'),
                                      if (marca.isNotEmpty || modelo.isNotEmpty)
                                        Text('$marca $modelo'),
                                    ],
                                  ),
                                ),

                                if (isAdmin)
                                  PopupMenuButton<String>(
                                    onSelected: (valor) {
                                      if (valor == 'editar') {
                                        abrirEdicao(viatura);
                                      }

                                      if (valor == 'status') {
                                        alterarStatus(viatura);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'editar',
                                        child: Text('Editar'),
                                      ),
                                      PopupMenuItem(
                                        value: 'status',
                                        child: Text(
                                          ativo ? 'Desativar' : 'Ativar',
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'KM atual: '
                              '${formatarKm(viatura['km_atual'])} km',
                            ),

                            const SizedBox(height: 8),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                textoManutencao(viatura),
                                style: TextStyle(
                                  color: cor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    ativo
                                        ? 'Ativa • ${viatura['status'] ?? 'DISPONÍVEL'}'
                                        : 'Desativada',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      abrirUltimasVistorias(viatura),
                                  icon: const Icon(Icons.history, size: 18),
                                  label: const Text('ÚLTIMAS VISTORIAS'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/* =========================================================
   CADASTRO / EDIÇÃO DE VIATURA
========================================================= */

class CadastroViaturaPage extends StatefulWidget {
  final Map<String, dynamic>? viatura;

  const CadastroViaturaPage({super.key, this.viatura});

  @override
  State<CadastroViaturaPage> createState() => _CadastroViaturaPageState();
}

class _CadastroViaturaPageState extends State<CadastroViaturaPage> {
  final prefixoController = TextEditingController();

  final placaController = TextEditingController();

  final chassiController = TextEditingController();

  final marcaController = TextEditingController();

  final modeloController = TextEditingController();

  final anoController = TextEditingController();

  final kmAtualController = TextEditingController();

  final kmManutencaoController = TextEditingController();

  final observacoesController = TextEditingController();

  String tipo = 'CARRO';

  String status = 'DISPONÍVEL';

  bool salvando = false;

  bool get editando => widget.viatura != null;

  String _normalizarStatusInicial(String? valor) {
    final bruto = (valor ?? '').trim().toUpperCase();
    if (bruto.contains('MANUTEN')) return 'EM MANUTENÇÃO';
    if (bruto == 'RESERVA') return 'RESERVA';
    if (bruto == 'BAIXADA') return 'BAIXADA';
    return 'DISPONÍVEL';
  }

  @override
  void initState() {
    super.initState();

    final v = widget.viatura;

    if (v == null) return;

    prefixoController.text = v['prefixo']?.toString() ?? '';

    placaController.text = v['placa']?.toString() ?? '';

    chassiController.text = v['chassi']?.toString() ?? '';

    marcaController.text = v['marca']?.toString() ?? '';

    modeloController.text = v['modelo']?.toString() ?? '';

    anoController.text = v['ano_fabricacao']?.toString() ?? '';

    kmAtualController.text = v['km_atual']?.toString() ?? '';

    kmManutencaoController.text = v['km_proxima_manutencao']?.toString() ?? '';

    observacoesController.text = v['observacoes']?.toString() ?? '';

    final tipoBruto = (v['tipo']?.toString() ?? 'CARRO').toUpperCase();
    tipo = tipoBruto == 'MOTO' ? 'MOTO' : 'CARRO';

    status = _normalizarStatusInicial(v['status']?.toString());
  }

  Future<void> salvar() async {
    if (salvando) return;

    final prefixo = prefixoController.text.trim();

    final placa = placaController.text.trim();

    final kmAtual = int.tryParse(kmAtualController.text.trim());

    final kmManutencao = int.tryParse(kmManutencaoController.text.trim());

    if (prefixo.isEmpty || placa.isEmpty) {
      mostrarMensagem('Informe prefixo e placa.');
      return;
    }

    if (kmAtual == null || kmManutencao == null) {
      mostrarMensagem('Informe os KM corretamente.');
      return;
    }

    if (kmManutencao < kmAtual) {
      mostrarMensagem(
        'A próxima manutenção não pode ser menor que o KM atual.',
      );
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      final headers = await SessionManager.getAuthHeaders();

      final dados = {
        'prefixo': prefixo,
        'placa': placa,
        'chassi': chassiController.text.trim(),
        'marca': marcaController.text.trim(),
        'modelo': modeloController.text.trim(),
        'tipo': tipo,
        'ano_fabricacao': int.tryParse(anoController.text.trim()),
        'km_atual': kmAtual,
        'km_proxima_manutencao': kmManutencao,
        'status': status,
        'observacoes': observacoesController.text.trim(),
      };

      http.Response resposta;

      if (editando) {
        final id = widget.viatura!['id']?.toString();

        if (id == null || id.isEmpty) {
          if (mounted) {
            setState(() {
              salvando = false;
            });
          }

          mostrarMensagem('ID da viatura não encontrado.');
          return;
        }

        resposta = await http
            .put(
              ApiConfig.viaturaEditarUri(id),
              headers: headers,
              body: jsonEncode(dados),
            )
            .timeout(const Duration(seconds: 10));
      } else {
        resposta = await http
            .post(
              ApiConfig.viaturasUri,
              headers: headers,
              body: jsonEncode(dados),
            )
            .timeout(const Duration(seconds: 10));
      }

      if (!mounted) return;

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        Navigator.of(context).pop(true);
        return;
      }

      mostrarMensagem(
        'Erro ao salvar viatura.\n'
        'Código: ${resposta.statusCode}',
      );
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem('Erro de conexão com o servidor.');

      debugPrint('ERRO CADASTRAR VIATURA: $e');
    } finally {
      if (mounted) {
        setState(() {
          salvando = false;
        });
      }
    }
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
    chassiController.dispose();
    marcaController.dispose();
    modeloController.dispose();
    anoController.dispose();
    kmAtualController.dispose();
    kmManutencaoController.dispose();
    observacoesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(editando ? 'Editar Viatura' : 'Nova Viatura')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: tipo,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'CARRO', child: Text('CARRO')),
                DropdownMenuItem(value: 'MOTO', child: Text('MOTO')),
              ],
              onChanged: salvando
                  ? null
                  : (valor) {
                      if (valor == null) {
                        return;
                      }

                      setState(() {
                        tipo = valor;
                      });
                    },
            ),

            const SizedBox(height: 15),

            campo(prefixoController, 'Prefixo'),

            campo(placaController, 'Placa'),

            campo(marcaController, 'Marca'),

            campo(modeloController, 'Modelo'),

            campo(
              anoController,
              'Ano de fabricação',
              teclado: TextInputType.number,
            ),

            campo(chassiController, 'Chassi'),

            campo(kmAtualController, 'KM atual', teclado: TextInputType.number),

            campo(
              kmManutencaoController,
              'KM da próxima manutenção',
              teclado: TextInputType.number,
            ),

            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'DISPONÍVEL',
                  child: Text('DISPONÍVEL'),
                ),
                DropdownMenuItem(
                  value: 'EM MANUTENÇÃO',
                  child: Text('EM MANUTENÇÃO'),
                ),
                DropdownMenuItem(value: 'RESERVA', child: Text('RESERVA')),
                DropdownMenuItem(value: 'BAIXADA', child: Text('BAIXADA')),
              ],
              onChanged: salvando
                  ? null
                  : (valor) {
                      if (valor == null) {
                        return;
                      }

                      setState(() {
                        status = valor;
                      });
                    },
            ),

            const SizedBox(height: 15),

            TextField(
              controller: observacoesController,
              enabled: !salvando,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: salvando ? null : salvar,
                icon: salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(salvando ? 'SALVANDO...' : 'SALVAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget campo(
    TextEditingController controller,
    String label, {
    TextInputType? teclado,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        enabled: !salvando,
        keyboardType: teclado,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/* =========================================================
   CHECKLIST (SAÍDA / ASSUNÇÃO E DEVOLUÇÃO / TÉRMINO)
========================================================= */

class ChecklistViaturaPage extends StatefulWidget {
  final Map<String, dynamic> viatura;
  final String tipoChecklist; // 'SAIDA' ou 'RETORNO'
  final int? kmReferencia;

  const ChecklistViaturaPage({
    super.key,
    required this.viatura,
    this.tipoChecklist = 'SAIDA',
    this.kmReferencia,
  });

  @override
  State<ChecklistViaturaPage> createState() => _ChecklistViaturaPageState();
}

class _ChecklistViaturaPageState extends State<ChecklistViaturaPage> {
  late List<String> itens;

  final Map<String, String> respostas = {};
  final Map<String, TextEditingController> obsItensControllers = {};

  final observacaoController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  final List<File> fotos = [];

  bool salvando = false;

  bool get isRetorno => widget.tipoChecklist.toUpperCase() == 'RETORNO';

  @override
  void initState() {
    super.initState();

    final tipo = (widget.viatura['tipo']?.toString() ?? 'CARRO').toUpperCase();

    if (tipo == 'MOTO') {
      if (isRetorno) {
        itens = [
          'Pneus',
          'Freios',
          'Óleo/Água',
          'Luzes',
          'Sirene/Giroflex',
          'Retrovisores',
          'Equipamentos',
          'Corrente/estado geral',
          'Limpeza da moto',
          'Combustível conferido',
        ];
      } else {
        itens = [
          'Pneus',
          'Freios',
          'Óleo/Água',
          'Luzes',
          'Sirene/Giroflex',
          'Retrovisores',
          'Equipamentos',
          'Corrente/estado geral',
        ];
      }
    } else {
      if (isRetorno) {
        itens = [
          'Pneus',
          'Freios',
          'Óleo/Água',
          'Luzes',
          'Sirene/Giroflex',
          'Vidros/retrovisores',
          'Equipamentos',
          'Lataria/novas avarias',
          'Limpeza interna/cabine',
          'Combustível conferido',
        ];
      } else {
        itens = [
          'Pneus',
          'Freios',
          'Óleo/Água',
          'Luzes',
          'Sirene/Giroflex',
          'Vidros/retrovisores',
          'Equipamentos',
          'Lataria/estado geral',
        ];
      }
    }

    for (final item in itens) {
      respostas[item] = 'OK';
      obsItensControllers[item] = TextEditingController();
    }
  }

  bool get existeProblema => respostas.values.contains('PROBLEMA');

  List<Map<String, String>> _montarListaItens() {
    return itens.map((item) {
      final st = respostas[item] ?? 'OK';
      final obsItem = st == 'PROBLEMA'
          ? (obsItensControllers[item]?.text.trim() ?? '')
          : '';
      return {
        'item': item,
        'status': st,
        'observacao': obsItem,
      };
    }).toList();
  }

  String _montarResumoProblemas(List<Map<String, String>> itensJson) {
    final problemas = <String>[];
    for (final it in itensJson) {
      if (it['status'] == 'PROBLEMA') {
        final nome = it['item'] ?? '';
        final obs = it['observacao'] ?? '';
        problemas.add(obs.isNotEmpty ? '$nome ($obs)' : nome);
      }
    }
    final obsGeral = observacaoController.text.trim();
    if (problemas.isEmpty && obsGeral.isEmpty) return '';
    final buffer = StringBuffer();
    if (problemas.isNotEmpty) {
      buffer.write('Itens com problema: ${problemas.join(", ")}');
    }
    if (obsGeral.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write('. ');
      buffer.write('Obs: $obsGeral');
    }
    return buffer.toString();
  }

  Future<void> selecionarFoto() async {
    if (salvando) return;

    if (fotos.length >= 5) {
      mostrarMensagem('Você pode enviar no máximo 5 fotos.');
      return;
    }

    try {
      final imagem = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (imagem == null || !mounted) return;

      setState(() {
        fotos.add(File(imagem.path));
      });
    } catch (e) {
      mostrarMensagem('Erro ao abrir a câmera: $e');
      debugPrint('ERRO FOTO CHECKLIST: $e');
    }
  }

  Future<void> selecionarDaGaleria() async {
    if (salvando) return;

    if (fotos.length >= 5) {
      mostrarMensagem('Você pode enviar no máximo 5 fotos.');
      return;
    }

    try {
      final imagens = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (imagens.isEmpty || !mounted) return;

      final espacoRestante = 5 - fotos.length;
      final selecionadas = imagens.take(espacoRestante).toList();

      setState(() {
        for (final img in selecionadas) {
          fotos.add(File(img.path));
        }
      });

      if (imagens.length > espacoRestante) {
        mostrarMensagem('Apenas 5 fotos podem ser enviadas por checklist.');
      }
    } catch (e) {
      mostrarMensagem('Erro ao abrir a galeria: $e');
      debugPrint('ERRO GALERIA CHECKLIST: $e');
    }
  }

  void removerFoto(int index) {
    if (salvando) return;

    setState(() {
      fotos.removeAt(index);
    });
  }

  Future<void> finalizarChecklist() async {
    if (salvando) return;
    final matriculaPolicial = await SessionManager.getMatricula();
    if (!mounted) return;

    final viaturaId = widget.viatura['id']?.toString();

    if (matriculaPolicial.isEmpty) {
      mostrarMensagem('Usuário não identificado.');
      return;
    }

    if (viaturaId == null || viaturaId.isEmpty) {
      mostrarMensagem('ID da viatura não encontrado.');
      return;
    }

    if (existeProblema && observacaoController.text.trim().isEmpty) {
      mostrarMensagem('Descreva o problema encontrado.');
      return;
    }

    if (existeProblema && fotos.isEmpty) {
      mostrarMensagem('Adicione pelo menos uma foto do problema encontrado.');
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      final itensJson = _montarListaItens();
      final resumoProblemas = _montarResumoProblemas(itensJson);

      final km = widget.kmReferencia ??
          (int.tryParse(widget.viatura['km_atual']?.toString() ?? '') ?? 0);

      final request = http.MultipartRequest(
        'POST',
        ApiConfig.checklistsUri,
      );

      final authHeaders =
          await SessionManager.getAuthHeaders(includeJsonContentType: false);
      request.headers.addAll(authHeaders);

      request.fields['viatura_id'] = viaturaId;
      request.fields['policial_matricula'] = matriculaPolicial;
      request.fields['km'] = km.toString();
      request.fields['status'] = existeProblema ? 'PROBLEMA' : 'OK';
      request.fields['tipo'] = widget.tipoChecklist;
      request.fields['observacao'] = observacaoController.text.trim();
      request.fields['itens'] = jsonEncode(itensJson);

      for (final foto in fotos) {
        request.files.add(
          await http.MultipartFile.fromPath('fotos', foto.path),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final resposta = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (resposta.statusCode != 201) {
        setState(() {
          salvando = false;
        });

        String mensagem = 'Erro ao salvar checklist.';
        try {
          final data = jsonDecode(resposta.body);
          mensagem = data['mensagem']?.toString() ?? mensagem;
        } catch (_) {}

        mostrarMensagem('$mensagem\nCódigo: ${resposta.statusCode}');
        return;
      }

      final resultado = Map<String, dynamic>.from(widget.viatura);
      resultado['tipo_checklist'] = widget.tipoChecklist;
      resultado['checklist_status'] = existeProblema ? 'PROBLEMA' : 'OK';
      resultado['checklist_observacao'] = observacaoController.text.trim();
      resultado['checklist_fotos'] = fotos.map((foto) => foto.path).toList();
      resultado['checklist_km'] = km;
      resultado['checklist_itens'] = itensJson;
      if (resumoProblemas.isNotEmpty) {
        resultado['checklist_resumo_problemas'] = resumoProblemas;
      }

      setState(() {
        salvando = false;
      });

      final tituloDialog = isRetorno
          ? 'Checklist de Devolução Concluído!'
          : 'Checklist de Assunção Concluído!';

      final tipoTexto = isRetorno
          ? 'Devolução (Término de Serviço)'
          : 'Assunção (Ao Pegar Viatura)';

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: Text(tituloDialog),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Vistoria de $tipoTexto finalizada com sucesso!',
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
                    const Icon(Icons.description, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Viatura: ${widget.viatura['prefixo'] ?? ''} (${widget.viatura['placa'] ?? ''})\n'
                        'Vistoria: $tipoTexto\n'
                        'Status: ${existeProblema ? "PROBLEMA" : "OK"}\n'
                        'KM: $km km',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Deseja enviar a planilha Excel (.xlsx) para o WhatsApp do Chefe da Companhia (+55 71 99988-1574)?',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () async {
                  Navigator.of(dialogCtx).pop();
                  await _compartilharArquivoExcelChecklist(
                    prefixo: widget.viatura['prefixo']?.toString() ?? '',
                    placa: widget.viatura['placa']?.toString() ?? '',
                    status: existeProblema ? 'PROBLEMA' : 'OK',
                    km: km.toString(),
                    observacao: observacaoController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.of(context).pop(resultado);
                  }
                },
                icon: const Icon(Icons.share),
                label: const Text('ENVIAR ARQUIVO EXCEL NO WHATSAPP (.XLSX)'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  Navigator.of(context).pop(resultado);
                },
                child: const Text('CONCLUIR SEM ENVIAR'),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        salvando = false;
      });

      mostrarMensagem('Erro de conexão com o servidor.');
      debugPrint('ERRO CHECKLIST: $e');
    }
  }

  Future<void> _compartilharArquivoExcelChecklist({
    required String prefixo,
    required String placa,
    required String status,
    required String km,
    required String observacao,
  }) async {
    try {
      final matriculaPolicial = await SessionManager.getMatricula();
      final nomePolicial = await SessionManager.getNome();

      final listaItens = _montarListaItens();

      final arquivoExcel = await ExcelExporter.gerarExcelChecklist(
        viatura: widget.viatura,
        matriculaPolicial: matriculaPolicial,
        nomePolicial: nomePolicial,
        statusGeral: status,
        km: km,
        observacao: observacao,
        itens: listaItens,
        tipo: widget.tipoChecklist,
      );

      final tipoTitulo = isRetorno
          ? '🏁 *CHECKLIST DE DEVOLUÇÃO (AO TERMINAR SERVIÇO)*'
          : '📋 *CHECKLIST DE ASSUNÇÃO (AO PEGAR VIATURA)*';

      final texto = '🚨 *PMBA - CONTROLE DE FROTA* 🚨\n'
          '$tipoTitulo\n\n'
          '🚗 *Viatura:* $prefixo (Placa: $placa)\n'
          '👮 *Policial:* $nomePolicial (Mat.: $matriculaPolicial)\n'
          '📊 *Status Geral:* ${status == "OK" ? "✅ APROVADO" : "⚠️ COM PROBLEMA"}\n'
          '🛣️ *${isRetorno ? "KM Final (Devolução)" : "KM Inicial (Assunção)"}:* $km km\n\n'
          '📎 Segue em anexo a planilha Excel (.xlsx) oficial do checklist gerada pelo aplicativo.';

      await ExcelExporter.compartilharExcel(
        arquivoExcel: arquivoExcel,
        textoMensagem: texto,
      );
    } catch (e) {
      mostrarMensagem('Erro ao gerar/compartilhar planilha Excel: $e');
    }
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  void dispose() {
    for (final ctrl in obsItensControllers.values) {
      ctrl.dispose();
    }
    observacaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefixo = widget.viatura['prefixo']?.toString() ?? '-';
    final placa = widget.viatura['placa']?.toString() ?? '-';
    final tipo = (widget.viatura['tipo']?.toString() ?? 'CARRO').toUpperCase();
    final kmExibido = widget.kmReferencia?.toString() ??
        (widget.viatura['km_atual']?.toString() ?? '0');

    final tituloPagina = isRetorno
        ? 'Checklist de Devolução (Término)'
        : 'Checklist de Saída (Pegar Viatura)';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(tituloPagina)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRetorno
                    ? Colors.teal.withValues(alpha: 0.15)
                    : Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isRetorno ? Colors.teal : Colors.blue,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isRetorno
                        ? Icons.assignment_return
                        : Icons.assignment_turned_in,
                    color: isRetorno ? Colors.teal : Colors.blue,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRetorno
                          ? 'Vistoria de Encerramento: inspecione as condições da viatura na devolução ao final do serviço.'
                          : 'Vistoria de Assunção: inspecione as condições da viatura antes de iniciar o turno de serviço.',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    tipo == 'MOTO' ? Icons.two_wheeler : Icons.directions_car,
                  ),
                ),
                title: Text(
                  prefixo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '$tipo • $placa\n'
                  'KM ${isRetorno ? "Final" : "Inicial"}: $kmExibido km',
                ),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              isRetorno
                  ? 'Itens de Vistoria na Devolução'
                  : 'Itens de Vistoria na Assunção',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            ...itens.map((item) {
              final resposta = respostas[item] ?? 'OK';
              final problema = resposta == 'PROBLEMA';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        problema ? Icons.warning : Icons.check_circle,
                        color: problema ? Colors.red : Colors.green,
                      ),
                      title: Text(item),
                      trailing: DropdownButton<String>(
                        value: resposta,
                        items: const [
                          DropdownMenuItem(value: 'OK', child: Text('OK')),
                          DropdownMenuItem(
                            value: 'PROBLEMA',
                            child: Text('PROBLEMA'),
                          ),
                        ],
                        onChanged: salvando
                            ? null
                            : (valor) {
                                if (valor == null) {
                                  return;
                                }

                                setState(() {
                                  respostas[item] = valor;
                                });
                              },
                      ),
                    ),
                    if (problema)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: TextField(
                          controller: obsItensControllers[item],
                          enabled: !salvando,
                          decoration: InputDecoration(
                            labelText: 'Qual o problema em $item? (opcional)',
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 15),

            if (existeProblema) ...[
              SeletorFotosWidget(
                fotos: fotos,
                salvando: salvando,
                onSelecionarCamera: selecionarFoto,
                onSelecionarGaleria: selecionarDaGaleria,
                onRemoverFoto: removerFoto,
              ),
              const SizedBox(height: 20),
            ],

            TextField(
              controller: observacaoController,
              enabled: !salvando,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: existeProblema
                    ? 'Descreva o problema encontrado *'
                    : 'Observações gerais da vistoria',
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            if (existeProblema)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Foi encontrada uma irregularidade. A observação e pelo menos 1 foto são obrigatórias.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: salvando ? null : finalizarChecklist,
                icon: salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  salvando
                      ? 'SALVANDO VISTORIA...'
                      : (isRetorno
                          ? 'CONCLUIR VISTORIA DE DEVOLUÇÃO'
                          : 'CONCLUIR VISTORIA DE ASSUNÇÃO'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================================================
   HISTÓRICO DE CHECKLISTS / VISTORIAS DA VIATURA
========================================================= */

class HistoricoChecklistsViaturaPage extends StatefulWidget {
  final Map<String, dynamic> viatura;

  const HistoricoChecklistsViaturaPage({super.key, required this.viatura});

  @override
  State<HistoricoChecklistsViaturaPage> createState() =>
      _HistoricoChecklistsViaturaPageState();
}

class _HistoricoChecklistsViaturaPageState
    extends State<HistoricoChecklistsViaturaPage> {
  List<ChecklistViaturaModel> checklists = [];
  bool carregando = true;
  String erro = '';

  @override
  void initState() {
    super.initState();
    carregarChecklists();
  }

  Future<void> carregarChecklists() async {
    if (!mounted) return;

    setState(() {
      carregando = true;
      erro = '';
    });

    final id = widget.viatura['id']?.toString() ?? '';
    if (id.isEmpty) {
      setState(() {
        carregando = false;
        erro = 'ID da viatura não encontrado.';
      });
      return;
    }

    try {
      final headers = await SessionManager.getAuthHeaders();
      final response = await http
          .get(
            ApiConfig.checklistsViaturaUri(id),
            headers: headers,
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          setState(() {
            checklists = data
                .whereType<Map>()
                .map((item) => ChecklistViaturaModel.fromMap(
                    Map<String, dynamic>.from(item)))
                .toList();
            carregando = false;
          });
          return;
        }
      }

      setState(() {
        carregando = false;
        erro = 'Erro ao carregar vistorias (Código: ${response.statusCode}).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        carregando = false;
        erro = 'Não foi possível conectar ao servidor.';
      });
      debugPrint('ERRO HISTORICO CHECKLIST: $e');
    }
  }

  String _formatarDataHora(DateTime? data) {
    if (data == null) return '-';
    final local = data.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  void _abrirFotoAmpliada(String urlFoto) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(
                  urlFoto,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Não foi possível carregar a imagem.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefixo = widget.viatura['prefixo']?.toString() ?? '-';
    final placa = widget.viatura['placa']?.toString() ?? '-';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Vistorias • $prefixo ($placa)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: carregando ? null : carregarChecklists,
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro.isNotEmpty
          ? RefreshIndicator(
              onRefresh: carregarChecklists,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(erro, textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            )
          : checklists.isEmpty
          ? RefreshIndicator(
              onRefresh: carregarChecklists,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(
                    child: Text('Nenhuma vistoria registrada para esta viatura.'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: carregarChecklists,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: checklists.length,
                itemBuilder: (context, index) {
                  final chk = checklists[index];
                  final problema = chk.temProblema;
                  final tipoLabel = chk.isRetorno ? 'DEVOLUÇÃO' : 'SAÍDA';
                  final kmTexto = chk.km == chk.km.roundToDouble()
                      ? chk.km.toInt().toString()
                      : chk.km.toStringAsFixed(1);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: Icon(
                        problema ? Icons.warning : Icons.check_circle,
                        color: problema ? Colors.red : Colors.green,
                      ),
                      title: Text(
                        '$tipoLabel • ${chk.status}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: problema ? Colors.redAccent : Colors.greenAccent,
                        ),
                      ),
                      subtitle: Text(
                        '${_formatarDataHora(chk.dataChecklist)} • KM: $kmTexto km\n'
                        'Matrícula: ${chk.policialMatricula}',
                      ),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const Divider(),
                        if (chk.observacao.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Observação geral: ${chk.observacao}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (chk.itens.isNotEmpty) ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Itens avaliados:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...chk.itens.map((it) {
                            final ok = it.isOk;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    ok ? Icons.check : Icons.close,
                                    size: 16,
                                    color: ok ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      it.observacao.isNotEmpty
                                          ? '${it.item} — ${it.status} (${it.observacao})'
                                          : '${it.item} — ${it.status}',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        if (chk.fotos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Fotos anexadas:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: chk.fotos.length,
                              itemBuilder: (context, fotoIdx) {
                                final url = ApiConfig.urlFoto(chk.fotos[fotoIdx]);
                                return GestureDetector(
                                  onTap: () => _abrirFotoAmpliada(url),
                                  child: Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          color: Colors.black26,
                                          child: const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
