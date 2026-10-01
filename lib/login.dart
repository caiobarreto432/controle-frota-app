import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'formulario_viatura.dart';
import 'services/session_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _matriculaController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _matriculaController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    final matricula = _matriculaController.text.trim();
    final senha = _senhaController.text;

    if (matricula.isEmpty || senha.isEmpty) {
      _mostrarErro('Por favor, preencha a matricula e a senha.');
      return;
    }

    // Sanitização e validação de formato da matrícula (somente dígitos alfanuméricos)
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(matricula)) {
      _mostrarErro('A matricula deve conter apenas numeros ou letras.');
      return;
    }

    setState(() {
      _carregando = true;
    });

    try {
      final response = await http
          .post(
            ApiConfig.loginUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'matricula': matricula, 'senha': senha}),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final usuario = (data['usuario'] as Map<String, dynamic>?) ?? {};

        final matriculaSalva = usuario['matricula']?.toString() ?? matricula;
        final nomeSalvo = usuario['nome']?.toString() ?? '';
        final perfilSalvo = usuario['perfil']?.toString() ?? 'POLICIAL';

        // Salva a sessão com segurança criptografada no dispositivo
        await SessionManager.saveSession(
          matricula: matriculaSalva,
          nome: nomeSalvo,
          perfil: perfilSalvo,
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FormularioViatura()),
        );
      } else {
        // Mensagem genérica para evitar vazamento de detalhes internos
        _mostrarErro('Matricula ou senha incorretos. Tente novamente.');
      }
    } on Exception {
      if (!mounted) return;
      _mostrarErro('Erro de conexao com o servidor. Verifique sua rede.');
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'logo_pmba',
                  child: Image.asset(
                    'assets/images/logo_pmba_transparente.png',
                    height: 140,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: const Color(0x0CFFFFFF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'POLICIA MILITAR DA BAHIA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC3B091),
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Controle de Viaturas',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _matriculaController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Matricula',
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          prefixIcon: const Icon(
                            Icons.badge,
                            color: Color(0xFFC3B091),
                          ),
                          filled: true,
                          fillColor: const Color(0x26000000),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _senhaController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFFC3B091),
                          ),
                          filled: true,
                          fillColor: const Color(0x26000000),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _carregando ? null : _fazerLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC3B091),
                            foregroundColor: const Color(0xFF2E1C1A),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _carregando
                              ? const CircularProgressIndicator(
                                  color: Color(0xFF2E1C1A),
                                )
                              : const Text(
                                  'ENTRAR',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Versao 1.0.0',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
