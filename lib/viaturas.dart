import 'widgets/seletor_fotos.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'services/session_manager.dart';

import 'package:image_picker/image_picker.dart';

import 'config.dart';

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
      final response = await http
          .get(
            Uri.parse(ApiConfig.viaturasUri.toString()),
            headers: {'x-matricula': matricula, 'Accept': 'application/json'},
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
          'CÃ³digo: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      mostrarMensagem('NÃ£o foi possÃ­vel conectar ao servidor.');

      debugPrint('ERRO VIATURAS: $e');
    }
  }

  Future<void> selecionarViatura(Map<String, dynamic> viatura) async {
    final ativo = viatura['ativo'] == true;

    if (!ativo) {
      mostrarMensagem('Esta viatura estÃ¡ desativada.');
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
       * Retorna a viatura para o formulÃ¡rio.
       */
      Navigator.of(context).pop(resultado);
    }
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
      mostrarMensagem('ID da viatura nÃ£o encontrado.');
      return;
    }

    final ativoAtual = viatura['ativo'] == true;

    try {
      final response = await http
          .put(
            Uri.parse(ApiConfig.viaturaStatusUri(id).toString()),
            headers: {
              'Content-Type': 'application/json',
              'x-admin-matricula': matricula,
            },
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
          'CÃ³digo: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem('Erro de conexÃ£o com o servidor.');

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
      return 'ManutenÃ§Ã£o vencida em '
          '${formatarKm(restante.abs())} km';
    }

    if (situacao == 'PROXIMA') {
      return 'Faltam '
          '${formatarKm(restante)} km';
    }

    return 'ManutenÃ§Ã£o em dia';
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
                                      Text('$tipo ? $placa'),
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
                              '${formatarKm(viatura['km_atual'])}',
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

                            Text(
                              ativo
                                  ? 'Ativa ? '
                                        '${viatura['status'] ?? 'DISPONÃVEL'}'
                                  : 'Desativada',
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
   CADASTRO / EDIÃ‡ÃƒO DE VIATURA
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

  String status = 'DISPONÃVEL';

  bool salvando = false;

  bool get editando => widget.viatura != null;

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

    tipo = v['tipo']?.toString().toUpperCase() ?? 'CARRO';

    status = v['status']?.toString() ?? 'DISPONÃVEL';
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
        'A prÃ³xima manutenÃ§Ã£o nÃ£o pode ser menor que o KM atual.',
      );
      return;
    }

    setState(() {
      salvando = true;
    });

    try {
      final matriculaAdmin = await SessionManager.getMatricula();

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

          mostrarMensagem('ID da viatura nÃ£o encontrado.');
          return;
        }

        resposta = await http
            .put(
              Uri.parse(ApiConfig.viaturaEditarUri(id).toString()),
              headers: {
                'Content-Type': 'application/json',
                'x-admin-matricula': matriculaAdmin,
              },
              body: jsonEncode(dados),
            )
            .timeout(const Duration(seconds: 10));
      } else {
        resposta = await http
            .post(
              Uri.parse(ApiConfig.viaturasUri.toString()),
              headers: {
                'Content-Type': 'application/json',
                'x-admin-matricula': matriculaAdmin,
              },
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
        'CÃ³digo: ${resposta.statusCode}',
      );
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem('Erro de conexÃ£o com o servidor.');

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
              'Ano de fabricaÃ§Ã£o',
              teclado: TextInputType.number,
            ),

            campo(chassiController, 'Chassi'),

            campo(kmAtualController, 'KM atual', teclado: TextInputType.number),

            campo(
              kmManutencaoController,
              'KM da prÃ³xima manutenÃ§Ã£o',
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
                  value: 'DISPONÃVEL',
                  child: Text('DISPONÃVEL'),
                ),
                DropdownMenuItem(
                  value: 'EM MANUTENÃ‡ÃƒO',
                  child: Text('EM MANUTENÃ‡ÃƒO'),
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
                labelText: 'ObservaÃ§Ãµes',
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
   CHECKLIST
========================================================= */

class ChecklistViaturaPage extends StatefulWidget {
  final Map<String, dynamic> viatura;

  const ChecklistViaturaPage({super.key, required this.viatura});

  @override
  State<ChecklistViaturaPage> createState() => _ChecklistViaturaPageState();
}

class _ChecklistViaturaPageState extends State<ChecklistViaturaPage> {
  late List<String> itens;

  final Map<String, String> respostas = {};

  final observacaoController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  final List<File> fotos = [];

  bool salvando = false;

  @override
  void initState() {
    super.initState();

    final tipo = (widget.viatura['tipo']?.toString() ?? 'CARRO').toUpperCase();

    if (tipo == 'MOTO') {
      itens = [
        'Pneus',
        'Freios',
        'Ã“leo/Ãgua',
        'Luzes',
        'Sirene/Giroflex',
        'Retrovisores',
        'Equipamentos',
        'Corrente/estado geral',
      ];
    } else {
      itens = [
        'Pneus',
        'Freios',
        'Ã“leo/Ãgua',
        'Luzes',
        'Sirene/Giroflex',
        'Vidros/retrovisores',
        'Equipamentos',
        'Lataria/estado geral',
      ];
    }

    for (final item in itens) {
      respostas[item] = 'OK';
    }
  }

  bool get existeProblema => respostas.values.contains('PROBLEMA');

  Future<void> selecionarFoto() async {
    if (salvando) return;

    if (fotos.length >= 5) {
      mostrarMensagem('VocÃª pode enviar no mÃ¡ximo 5 fotos.');
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
      if (!mounted) return;
      mostrarMensagem('NÃ£o foi possÃ­vel abrir a cÃ¢mera.');
      debugPrint('ERRO FOTO CHECKLIST: $e');
    }
  }

  Future<void> selecionarDaGaleria() async {
    if (salvando) return;

    if (fotos.length >= 5) {
      mostrarMensagem('VocÃª pode enviar no mÃ¡ximo 5 fotos.');
      return;
    }

    try {
      final imagens = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (!mounted || imagens.isEmpty) return;

      final restantes = 5 - fotos.length;
      final selecionadas = imagens.take(restantes);

      setState(() {
        fotos.addAll(selecionadas.map((item) => File(item.path)));
      });

      if (imagens.length > restantes) {
        mostrarMensagem('Apenas 5 fotos podem ser enviadas por checklist.');
      }
    } catch (e) {
      if (!mounted) return;
      mostrarMensagem('NÃ£o foi possÃ­vel abrir a galeria.');
      debugPrint('ERRO GALERIA CHECKLIST: $e');
    }
  }

  void removerFoto(int index) {
    if (salvando || !mounted) return;

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
      mostrarMensagem('UsuÃ¡rio nÃ£o identificado.');
      return;
    }

    if (viaturaId == null || viaturaId.isEmpty) {
      mostrarMensagem('ID da viatura nÃ£o encontrado.');
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
      final itensJson = itens.map((item) {
        return {
          'item': item,
          'status': respostas[item] ?? 'OK',
          'observacao': '',
        };
      }).toList();

      final km =
          int.tryParse(widget.viatura['km_atual']?.toString() ?? '') ?? 0;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.checklistsUri.toString()),
      );

      request.fields['viatura_id'] = viaturaId;
      request.fields['policial_matricula'] = matriculaPolicial;
      request.fields['km'] = km.toString();
      request.fields['status'] = existeProblema ? 'PROBLEMA' : 'OK';
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

      debugPrint(
        'CHECKLIST STATUS: '
        '${resposta.statusCode}',
      );

      if (resposta.statusCode != 201) {
        setState(() {
          salvando = false;
        });

        String mensagem = 'Erro ao salvar checklist.';

        try {
          final data = jsonDecode(resposta.body);

          mensagem = data['mensagem']?.toString() ?? mensagem;
        } catch (_) {}

        mostrarMensagem(
          '$mensagem\n'
          'CÃ³digo: ${resposta.statusCode}',
        );

        return;
      }

      final resultado = Map<String, dynamic>.from(widget.viatura);

      resultado['checklist_status'] = existeProblema ? 'PROBLEMA' : 'OK';

      resultado['checklist_observacao'] = observacaoController.text.trim();

      resultado['checklist_fotos'] = fotos.map((foto) => foto.path).toList();

      /*
       * SÃ³ agora fechamos o checklist.
       *
       * NÃ£o hÃ¡ setState depois do pop.
       */
      Navigator.of(context).pop(resultado);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        salvando = false;
      });

      mostrarMensagem('Erro de conexÃ£o com o servidor.');

      debugPrint('ERRO CHECKLIST: $e');
    }
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  void dispose() {
    observacaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefixo = widget.viatura['prefixo']?.toString() ?? '-';

    final placa = widget.viatura['placa']?.toString() ?? '-';

    final tipo = (widget.viatura['tipo']?.toString() ?? 'CARRO').toUpperCase();

    final km = widget.viatura['km_atual']?.toString() ?? '0';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Checklist')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  '$tipo ? $placa\n'
                  'KM: $km',
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Checklist da viatura',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            ...itens.map((item) {
              final resposta = respostas[item] ?? 'OK';

              final problema = resposta == 'PROBLEMA';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
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
                    ? 'Descreva o problema *'
                    : 'ObservaÃ§Ã£o geral',
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
                        'Foi encontrada uma irregularidade. A observaÃ§Ã£o Ã© obrigatÃ³ria.',
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
                label: Text(salvando ? 'SALVANDO...' : 'FINALIZAR CHECKLIST'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
