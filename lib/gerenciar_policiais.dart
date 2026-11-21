import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'config.dart';
import 'models/policial_model.dart';
import 'services/session_manager.dart';
import 'widgets/fundo_pmba.dart';

class GerenciarPoliciaisPage extends StatefulWidget {
  const GerenciarPoliciaisPage({super.key});

  @override
  State<GerenciarPoliciaisPage> createState() => _GerenciarPoliciaisPageState();
}

class _GerenciarPoliciaisPageState extends State<GerenciarPoliciaisPage> {
  final nomeController = TextEditingController();
  final matriculaController = TextEditingController();
  final patenteController = TextEditingController();
  final emailController = TextEditingController();
  final celularController = TextEditingController();
  final senhaController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  List<PolicialModel> policiais = [];

  File? fotoSelecionada;

  bool carregando = false;

  @override
  void initState() {
    super.initState();
    carregarPoliciais();
  }

  Future<void> escolherFoto() async {
    final opcao = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Escolher da galeria'),
                onTap: () {
                  Navigator.pop(context, 'galeria');
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tirar foto com a câmera'),
                onTap: () {
                  Navigator.pop(context, 'camera');
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );

    if (opcao == null) {
      return;
    }

    try {
      XFile? imagem;

      if (opcao == 'galeria') {
        imagem = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1200,
          maxHeight: 1200,
        );
      } else if (opcao == 'camera') {
        imagem = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1200,
          maxHeight: 1200,
        );
      }

      if (imagem == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        fotoSelecionada = File(imagem!.path);
      });

      mostrarMensagem('Foto selecionada com sucesso.');
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem(
        'Não foi possível acessar a câmera ou galeria. Verifique as permissões do aplicativo.',
      );

      debugPrint('ERRO IMAGE PICKER: $e');
    }
  }

  Future<void> carregarPoliciais() async {
    try {
      final headers = await SessionManager.getAuthHeaders();
      final resposta = await http
          .get(
            ApiConfig.policiaisUri,
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);

        if (dados is List) {
          setState(() {
            policiais = dados
                .whereType<Map>()
                .map((item) =>
                    PolicialModel.fromMap(Map<String, dynamic>.from(item)))
                .toList();
          });
        }
      } else {
        mostrarMensagem(
          'Erro ao carregar policiais:\n${resposta.body}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem('Erro de conexão com o servidor.');

      debugPrint('ERRO CARREGAR POLICIAIS: $e');
    }
  }

  Future<void> cadastrarPolicial() async {
    final nome = nomeController.text.trim();
    final matricula = matriculaController.text.trim();
    final patente = patenteController.text.trim();
    final email = emailController.text.trim();
    final celular = celularController.text.trim();
    final senha = senhaController.text;

    if (nome.isEmpty) {
      mostrarMensagem('Informe o nome do policial.');
      return;
    }

    if (matricula.isEmpty) {
      mostrarMensagem('Informe a matrícula.');
      return;
    }

    if (senha.isEmpty) {
      mostrarMensagem('Informe a senha.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final requisicao = http.MultipartRequest(
        'POST',
        ApiConfig.policiaisUri,
      );

      final authHeaders = await SessionManager.getAuthHeaders(includeJsonContentType: false);
      requisicao.headers.addAll(authHeaders);

      requisicao.fields['nome'] = nome;
      requisicao.fields['matricula'] = matricula;
      requisicao.fields['patente'] = patente;
      requisicao.fields['email'] = email;
      requisicao.fields['numero_celular'] = celular;
      requisicao.fields['senha'] = senha;
      requisicao.fields['perfil'] = 'POLICIAL';

      if (fotoSelecionada != null) {
        requisicao.files.add(
          await http.MultipartFile.fromPath('foto', fotoSelecionada!.path),
        );
      }

      final resposta = await requisicao.send();

      final corpo = await resposta.stream.bytesToString();

      if (!mounted) return;

      if (resposta.statusCode == 201) {
        limparFormulario();

        await carregarPoliciais();

        mostrarMensagem('Policial cadastrado com sucesso!');
      } else {
        try {
          final dados = jsonDecode(corpo);

          mostrarMensagem(
            dados['mensagem']?.toString() ?? 'Erro ao cadastrar policial.',
          );
        } catch (_) {
          mostrarMensagem('Erro ao cadastrar policial:\n$corpo');
        }
      }
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem('Erro de conexão com o servidor.');

      debugPrint('ERRO CADASTRO POLICIAL: $e');
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> desativarPolicial(String id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Desativar policial'),
          content: Text('Deseja desativar $nome?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Desativar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      final headers = await SessionManager.getAuthHeaders();
      final resposta = await http
          .put(
            ApiConfig.policialDesativarUri(id),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        await carregarPoliciais();

        mostrarMensagem('Policial desativado.');
      } else {
        mostrarMensagem(
          'Erro ao desativar:\n${resposta.body}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      mostrarMensagem('Erro de conexão.');

      debugPrint('ERRO DESATIVAR POLICIAL: $e');
    }
  }

  void limparFormulario() {
    nomeController.clear();
    matriculaController.clear();
    patenteController.clear();
    emailController.clear();
    celularController.clear();
    senhaController.clear();

    setState(() {
      fotoSelecionada = null;
    });
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  void dispose() {
    nomeController.dispose();
    matriculaController.dispose();
    patenteController.dispose();
    emailController.dispose();
    celularController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    TextInputType? type,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: const Color(0x26000000),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FundoPMBA(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Gerenciar Policiais',
            style: TextStyle(
              color: Color(0xFFC3B091),
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Color(0xFFC3B091)),
        ),
        body: RefreshIndicator(
          onRefresh: carregarPoliciais,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: const Color(0x0CFFFFFF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cadastrar Policial',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC3B091),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(nomeController, 'Nome completo'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      patenteController,
                      'Patente',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      matriculaController,
                      'Matrícula',
                      type: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      emailController,
                      'E-mail',
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      celularController,
                      'Número de Celular',
                      type: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(senhaController, 'Senha', obscure: true),
                    const SizedBox(height: 24),
                    if (fotoSelecionada != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            fotoSelecionada!,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: escolherFoto,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: const Color(0xFFC3B091)
                                .withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Icon(
                          Icons.add_a_photo,
                          color: const Color(0xFFC3B091).withValues(alpha: 0.8),
                        ),
                        label: Text(
                          fotoSelecionada == null
                              ? 'ADICIONAR FOTO'
                              : 'TROCAR FOTO',
                          style: const TextStyle(color: Color(0xFFC3B091)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: carregando ? null : cadastrarPolicial,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC3B091),
                          foregroundColor: const Color(0xFF2E1C1A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: carregando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2E1C1A),
                                ),
                              )
                            : const Icon(Icons.person_add),
                        label: Text(
                          carregando ? 'CADASTRANDO...' : 'CADASTRAR POLICIAL',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Policiais cadastrados',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC3B091),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              if (policiais.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Nenhum policial encontrado.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ...policiais.map((policial) {
                final nome = policial.nome;
                final matricula = policial.matricula;
                final patente = policial.patente ?? '';
                final email = policial.email ?? '';
                final celular = policial.numeroCelular ?? '';
                final perfil = policial.perfil;
                final ativo = policial.ativo;
                final foto = policial.foto;

                final subtituloLinhas = [
                  if (patente.isNotEmpty) 'Patente: $patente',
                  'Matrícula: $matricula',
                  if (email.isNotEmpty) 'E-mail: $email',
                  if (celular.isNotEmpty) 'Celular: $celular',
                  'Perfil: $perfil',
                  'Status: ${ativo ? "Ativo" : "Inativo"}',
                ].join('\n');

                return Card(
                  color: const Color(0x0CFFFFFF),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: foto != null && foto.isNotEmpty
                        ? CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage(
                              ApiConfig.urlFoto(foto),
                            ),
                          )
                        : CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0x26000000),
                            child: Text(
                              nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Color(0xFFC3B091),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    title: Text(
                      nome,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        subtituloLinhas,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: ativo
                        ? IconButton(
                            icon: const Icon(
                              Icons.block,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Desativar',
                            onPressed: () {
                              desativarPolicial(
                                policial.id.toString(),
                                nome,
                              );
                            },
                          )
                        : const Icon(Icons.person_off, color: Colors.grey),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
