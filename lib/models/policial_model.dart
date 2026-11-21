import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Modelo de dados imutável representando um Policial.
@immutable
class PolicialModel {
  final int id;
  final String nome;
  final String matricula;
  final String perfil;
  final bool ativo;
  final String? foto;
  final String? email;
  final String? patente;
  final String? numeroCelular;

  const PolicialModel({
    required this.id,
    required this.nome,
    required this.matricula,
    this.perfil = 'POLICIAL',
    this.ativo = true,
    this.foto,
    this.email,
    this.patente,
    this.numeroCelular,
  });

  bool get isAdmin => perfil.toUpperCase() == 'ADMIN';

  factory PolicialModel.fromMap(Map<String, dynamic> map) {
    return PolicialModel(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      nome: (map['nome'] as String?)?.trim() ?? '',
      matricula: (map['matricula'] as String?)?.trim() ?? '',
      perfil: (map['perfil'] as String?)?.trim().toUpperCase() ?? 'POLICIAL',
      ativo: map['ativo'] == true || map['ativo']?.toString() == 'true',
      foto: map['foto']?.toString().trim(),
      email: map['email']?.toString().trim(),
      patente: map['patente']?.toString().trim(),
      numeroCelular: (map['numero_celular'] ?? map['celular'] ?? map['telefone'])
          ?.toString()
          .trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'matricula': matricula,
        'perfil': perfil,
        'ativo': ativo,
        'foto': foto,
        'email': email,
        'patente': patente,
        'numero_celular': numeroCelular,
      };

  String toJson() => jsonEncode(toMap());

  factory PolicialModel.fromJson(String source) =>
      PolicialModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

