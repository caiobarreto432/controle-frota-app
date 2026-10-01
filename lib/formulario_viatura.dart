import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'services/session_manager.dart';

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

  bool checklistConcluido = false;

  @override
  void initState() {
    super.initState();
    carregarUsuario();
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
    /*
     * Fecha o Drawer somente se ele estiver aberto.
     */
    final scaffold = Scaffold.maybeOf(context);

    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();

      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    /*
     * Abre ViaturasPage.
     *
     * A ViaturasPage retorna o resultado do checklist
     * através de não).
     */
    final resultado = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const ViaturasPage()),
    );

    if (!mounted) return;

    if (resultado == null) {
      return;
    }

    final viatura = Map<String, dynamic>.from(resultado);

    setState(() {
      viaturaSelecionada = viatura;

      checklistConcluido = viatura['checklist_status'] != null;

      prefixoController.text = viatura['prefixo']?.toString() ?? '';

      placaController.text = viatura['placa']?.toString() ?? '';

      kmInicialController.text = viatura['km_atual']?.toString() ?? '';
    });

    mostrarMensagem('Checklist concluído. Viatura selecionada.');
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

  Future<void> refazerChecklist() async {
    final viatura = viaturaSelecionada;

    if (viatura == null) {
      mostrarMensagem('Nenhuma viatura selecionada.');
      return;
    }

    final resultado = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) =>
            ChecklistViaturaPage(viatura: Map<String, dynamic>.from(viatura)),
      ),
    );

    if (!mounted) return;

    if (resultado == null) {
      return;
    }

    final novaViatura = Map<String, dynamic>.from(resultado);

    setState(() {
      viaturaSelecionada = novaViatura;

      checklistConcluido = novaViatura['checklist_status'] != null;

      prefixoController.text = novaViatura['prefixo']?.toString() ?? '';

      placaController.text = novaViatura['placa']?.toString() ?? '';

      kmInicialController.text = novaViatura['km_atual']?.toString() ?? '';
    });

    mostrarMensagem('Checklist concluído.');
  }

  Future<void> salvarRegistro() async {
    if (salvando) return;

    final viatura = viaturaSelecionada;

    if (viatura == null) {
      mostrarMensagem('Selecione uma viatura antes de salvar.');
      return;
    }

    if (!checklistConcluido) {
      mostrarMensagem('Finalize o checklist antes de registrar a saída.');
      return;
    }

    final prefixo = prefixoController.text.trim();

    final placa = placaController.text.trim();

    final kmInicial = int.tryParse(kmInicialController.text.trim());

    final kmFinal = int.tryParse(kmFinalController.text.trim());

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
        'combustivel_inicial': abasteceu
            ? double.tryParse(litrosController.text.trim()) ?? 0
            : 0,
        'combustivel_final': abasteceu
            ? double.tryParse(valorController.text.trim()) ?? 0
            : 0,
        'ocorrencias': avariasController.text.trim(),
        'observacoes': observacoesController.text.trim(),
      };

      final resposta = await http
          .post(
            Uri.parse(ApiConfig.salvarRegistroUri.toString()),
            headers: {
              'Content-Type': 'application/json',
              'x-matricula': matriculaPolicial,
            },
            body: jsonEncode(dados),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        limparFormulario();

        mostrarMensagem('Registro salvo com sucesso!');
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
    prefixoController.clear();
    placaController.clear();
    kmInicialController.clear();
    kmFinalController.clear();
    litrosController.clear();
    valorController.clear();
    avariasController.clear();
    observacoesController.clear();

    if (!mounted) return;

    setState(() {
      abasteceu = false;
      viaturaSelecionada = null;
      checklistConcluido = false;
    });
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
                      ? 'Toque para selecionar viatura e preencher o checklist.'
                      : ' - '
                            '\n'
                            'KM atual: '
                            '${viaturaSelecionada!['km_atual'] ?? 0}',
                ),

                trailing: Icon(
                  checklistConcluido ? Icons.check_circle : Icons.arrow_forward,
                  color: checklistConcluido ? Colors.green : null,
                ),

                onTap: abrirViaturas,
              ),
            ),

            if (viaturaSelecionada != null) ...[
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: salvando ? null : refazerChecklist,
                  icon: const Icon(Icons.checklist),
                  label: const Text('REFAZER CHECKLIST'),
                ),
              ),
            ],

            const SizedBox(height: 18),

            TextFormField(
              initialValue: dataAtual(),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Data',
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
              'KM Inicial',
              somenteLeitura: viaturaSelecionada != null,
              teclado: TextInputType.number,
            ),

            campo(kmFinalController, 'KM Final', teclado: TextInputType.number),

            Card(
              child: SwitchListTile(
                title: const Text('Abasteceu?'),
                subtitle: Text(abasteceu ? 'Sim' : 'não'),
                value: abasteceu,
                onChanged: salvando
                    ? null
                    : (valor) {
                        setState(() {
                          abasteceu = valor;
                        });
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

            campo(avariasController, 'Avarias', linhas: 4),

            campo(observacoesController, 'Observações', linhas: 4),

            if (!checklistConcluido)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 5),
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
                        'Selecione o checklist antes de registrar a saída.',
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
                label: Text(salvando ? 'SALVANDO...' : 'SALVAR REGISTRO'),
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
