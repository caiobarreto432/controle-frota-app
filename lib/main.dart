import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'formulario_viatura.dart';
import 'login.dart';
import 'services/session_manager.dart';
import 'widgets/fundo_pmba.dart';

const Color pmbaMarrom = Color(0xFF4A3B32);
const Color pmbaCaqui = Color(0xFFC3B091);
const Color pmbaAzul = Color(0xFF0033A0);
const Color pmbaVermelho = Color(0xFFDA291C);

const FlexSchemeColor pmbaSchemeDark = FlexSchemeColor(
  primary: pmbaCaqui,
  primaryContainer: pmbaMarrom,
  secondary: pmbaAzul,
  secondaryContainer: pmbaVermelho,
  tertiary: Colors.white70,
  tertiaryContainer: Colors.white38,
  appBarColor: pmbaMarrom,
  error: Colors.redAccent,
);

void main() {
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Controle de Viaturas',
      themeMode: ThemeMode.dark,
      theme: FlexThemeData.light(
        colors: pmbaSchemeDark,
        useMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
      ),
      darkTheme: FlexThemeData.dark(
        colors: pmbaSchemeDark,
        useMaterial3: true,
        scaffoldBackground: Colors.transparent,
        fontFamily: GoogleFonts.inter().fontFamily,
        subThemesData: const FlexSubThemesData(
          defaultRadius: 16.0,
          inputDecoratorIsFilled: false,
          inputDecoratorFillColor: Colors.transparent,
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorUnfocusedHasBorder: false,
          inputDecoratorFocusedHasBorder: true,
          inputDecoratorFocusedBorderWidth: 1.0,
          cardElevation: 12.0,
        ),
      ),
      builder: (context, child) {
        return FundoPMBA(child: child ?? const SizedBox());
      },
      home: FutureBuilder<bool>(
        future: SessionManager.isLoggedIn(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final bool logado = snapshot.data!;
          return logado ? const FormularioViatura() : const LoginPage();
        },
      ),
    );
  }
}
