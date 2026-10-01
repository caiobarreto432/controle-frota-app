import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'config.dart';
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

  List<dynamic> policiais = [];

  File? fotoSelecionada;

  bool carregando = false;
  String matriculaAdmin = '';

  @override
  void initState() {
    super.initState();
    inicializar();
  }

  Future<void> inicializar() async {
    matriculaAdmin = await SessionManager.getMatricula();
    await carregarPoliciais();
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
      headers['x-admin-matricula'] = matriculaAdmin;

      final resposta = await http
          .get(Uri.parse(ApiConfig.policiaisUri.toString()), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);

        if (dados is List) {
          setState(() {
            policiais = dados;
          });
        }
      } else {
        mostrarMensagem('Erro ao carregar policiais:\n${resposta.body}');
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
        Uri.parse(ApiConfig.policiaisUri.toString()),
      );

      final headers = await SessionManager.getAuthHeaders();
      requisicao.headers.addAll(headers);
      requisicao.headers['x-admin-matricula'] = matriculaAdmin;

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
      headers['x-admin-matricula'] = matriculaAdmin;

      final resposta = await http
          .put(
            Uri.parse(ApiConfig.policialDesativarUri(id).toString()),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        await carregarPoliciais();

        mostrarMensagem('Policial desativado.');
      } else {
        mostrarMensagem('Erro ao desativar:\n${resposta.body}');
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

  Widget _buildItemInfoRow({
    required IconData icon,
    required String label,
    required String valor,
    Color? colorValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFFC3B091).withValues(alpha: 0.8),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                color: colorValue ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
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
                    _buildTextField(patenteController, 'Patente'),
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
                final id = policial['id']?.toString() ?? '';
                final nome = policial['nome']?.toString() ?? '';
                final matricula = policial['matricula']?.toString() ?? '';
                final patente = policial['patente']?.toString() ?? '';
                final email = policial['email']?.toString() ?? '';
                final celular =
                    (policial['numero_celular'] ??
                            policial['celular'] ??
                            policial['telefone'])
                        ?.toString() ??
                    '';
                final perfil = policial['perfil']?.toString() ?? '';
                final ativo = policial['ativo'] == true;
                final foto = policial['foto']?.toString();

                return Card(
                  color: const Color(0x0CFFFFFF),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ativo
                                      ? Colors.greenAccent
                                      : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: const Color(0x26000000),
                                backgroundImage:
                                    (foto != null && foto.isNotEmpty)
                                    ? NetworkImage(ApiConfig.urlFoto(foto))
                                    : null,
                                child: (foto == null || foto.isEmpty)
                                    ? Text(
                                        nome.isNotEmpty
                                            ? nome[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Color(0xFFC3B091),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nome.isNotEmpty
                                        ? nome
                                        : 'Policial sem nome',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (patente.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFC3B091)
                                                .withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            patente,
                                            style: const TextStyle(
                                              color: Color(0xFFC3B091),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          perfil.isNotEmpty
                                              ? perfil
                                              : 'POLICIAL',
                                          style: const TextStyle(
                                            color: Colors.blueAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ativo
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    ativo ? 'Ativo' : 'Inativo',
                                    style: TextStyle(
                                      color: ativo
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (ativo)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.block,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    tooltip: 'Desativar Policial',
                                    onPressed: () {
                                      desativarPolicial(
                                        policial['id'].toString(),
                                        nome,
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: Colors.white12, height: 1),
                        ),
                        _buildItemInfoRow(
                          icon: Icons.fingerprint,
                          label: 'ID no Sistema',
                          valor: id.isNotEmpty ? id : 'N/A',
                        ),
                        _buildItemInfoRow(
                          icon: Icons.badge,
                          label: 'Matrícula',
                          valor: matricula.isNotEmpty
                              ? matricula
                              : 'Não informada',
                        ),
                        _buildItemInfoRow(
                          icon: Icons.shield,
                          label: 'Patente / Graduação',
                          valor: patente.isNotEmpty ? patente : 'Não informada',
                        ),
                        _buildItemInfoRow(
                          icon: Icons.email,
                          label: 'E-mail',
                          valor: email.isNotEmpty ? email : 'Não informado',
                        ),
                        _buildItemInfoRow(
                          icon: Icons.phone,
                          label: 'Celular / Telefone',
                          valor: celular.isNotEmpty ? celular : 'Não informado',
                        ),
                        _buildItemInfoRow(
                          icon: Icons.admin_panel_settings,
                          label: 'Perfil de Acesso',
                          valor: perfil.isNotEmpty ? perfil : 'POLICIAL',
                        ),
                        _buildItemInfoRow(
                          icon: Icons.check_circle_outline,
                          label: 'Status no Sistema',
                          valor: ativo
                              ? 'Ativo (Acesso Liberado)'
                              : 'Inativo (Acesso Bloqueado)',
                          colorValue: ativo
                              ? Colors.greenAccent
                              : Colors.redAccent,
                        ),
                      ],
                    ),
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
