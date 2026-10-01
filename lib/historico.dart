import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'services/session_manager.dart';

import 'config.dart';

class HistoricoPage extends StatefulWidget {
  const HistoricoPage({super.key});

  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  List<dynamic> registros = [];

  bool carregando = true;

  String erro = '';

  String matriculaUsuario = '';

  String perfilUsuario = 'POLICIAL';

  @override
  void initState() {
    super.initState();
    inicializar();
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
      final resposta = await http
          .get(
            Uri.parse(ApiConfig.registrosUri.toString()),
            headers: {
              'x-matricula': matriculaUsuario,
              'x-admin-matricula': matriculaUsuario,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);

        if (dados is List) {
          setState(() {
            registros = dados;
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

  Widget linhaAbastecimento(Map<String, dynamic> registro) {
    final litros = registro['combustivel_inicial'];

    final valorPago = registro['combustivel_final'];

    final abasteceu = (double.tryParse(litros?.toString() ?? '') ?? 0) > 0;

    if (!abasteceu) {
      return linha('Abastecimento', 'Não');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        linha('Abastecimento', 'Sim'),
        linha('Litros abastecidos', formatarLitros(litros)),
        linha('Valor pago', formatarReais(valorPago)),
      ],
    );
  }

  Widget construirRegistro(Map<String, dynamic> registro) {
    final prefixo = registro['prefixo_viatura']?.toString().trim() ?? '';

    final placa = registro['placa_viatura']?.toString().trim() ?? '';

    final nome = registro['nome_policial']?.toString() ?? 'Sem nome';

    final titulo = placa.isEmpty
        ? (prefixo.isEmpty ? 'Viatura' : prefixo)
        : prefixo.isEmpty
        ? placa
        : '$prefixo ? $placa';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.directions_car)),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$nome ? '
          '${formatarData(registro['data_servico'])}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),

          linha('Policial', registro['nome_policial']),

          linha('Matrícula', registro['matricula']),

          linha('Data', formatarData(registro['data_servico'])),

          linha('Prefixo', registro['prefixo_viatura']),

          linha('Placa', registro['placa_viatura']),

          linha('KM inicial', formatarNumero(registro['km_inicial'])),

          linha('KM final', formatarNumero(registro['km_final'])),

          const SizedBox(height: 4),

          linhaAbastecimento(registro),

          linha('Avarias', registro['ocorrencias']),

          linha('Observações', registro['observacoes']),
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

    return RefreshIndicator(
      onRefresh: carregarRegistros,
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: registros.length,
        itemBuilder: (context, index) {
          final registro = Map<String, dynamic>.from(registros[index]);

          return construirRegistro(registro);
        },
      ),
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
