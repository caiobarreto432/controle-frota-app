import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Modelo de dados imutável representando um Registro de Serviço / Saída de Viatura.
@immutable
class RegistroServicoModel {
  final int id;
  final String nomePolicial;
  final String matricula;
  final DateTime? dataServico;
  final String prefixoViatura;
  final String placaViatura;
  final double kmInicial;
  final double kmFinal;
  final double litrosAbastecidos;
  final double valorAbastecimento;
  final String ocorrencias;
  final String observacoes;
  final DateTime? criadoEm;
  final String? planilhaUrl;

  const RegistroServicoModel({
    required this.id,
    required this.nomePolicial,
    required this.matricula,
    this.dataServico,
    required this.prefixoViatura,
    required this.placaViatura,
    this.kmInicial = 0.0,
    this.kmFinal = 0.0,
    this.litrosAbastecidos = 0.0,
    this.valorAbastecimento = 0.0,
    this.ocorrencias = '',
    this.observacoes = '',
    this.criadoEm,
    this.planilhaUrl,
  });

  /// Quilometragem total rodada durante o serviço.
  double get kmRodado => (kmFinal >= kmInicial) ? (kmFinal - kmInicial) : 0.0;

  /// Indica se houve abastecimento registrado.
  bool get houveAbastecimento => litrosAbastecidos > 0 || valorAbastecimento > 0;

  /// Título formatado com prefixo e placa da viatura.
  String get tituloViatura {
    if (placaViatura.isEmpty) {
      return prefixoViatura.isEmpty ? 'Viatura' : prefixoViatura;
    }
    return prefixoViatura.isEmpty ? placaViatura : '$prefixoViatura • $placaViatura';
  }

  factory RegistroServicoModel.fromMap(Map<String, dynamic> map) {
    return RegistroServicoModel(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      nomePolicial: (map['nome_policial'] as String?)?.trim() ?? 'Sem nome',
      matricula: (map['matricula'] as String?)?.trim() ?? '',
      dataServico: DateTime.tryParse(map['data_servico']?.toString() ?? ''),
      prefixoViatura: (map['prefixo_viatura'] as String?)?.trim() ?? '',
      placaViatura: (map['placa_viatura'] as String?)?.trim() ?? '',
      kmInicial: double.tryParse(map['km_inicial']?.toString() ?? '') ?? 0.0,
      kmFinal: double.tryParse(map['km_final']?.toString() ?? '') ?? 0.0,
      litrosAbastecidos:
          double.tryParse(map['combustivel_inicial']?.toString() ?? '') ?? 0.0,
      valorAbastecimento:
          double.tryParse(map['combustivel_final']?.toString() ?? '') ?? 0.0,
      ocorrencias: (map['ocorrencias'] as String?)?.trim() ?? '',
      observacoes: (map['observacoes'] as String?)?.trim() ?? '',
      criadoEm: DateTime.tryParse(map['criado_em']?.toString() ?? ''),
      planilhaUrl: map['planilha_url']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome_policial': nomePolicial,
        'matricula': matricula,
        'data_servico': dataServico?.toIso8601String(),
        'prefixo_viatura': prefixoViatura,
        'placa_viatura': placaViatura,
        'km_inicial': kmInicial,
        'km_final': kmFinal,
        'combustivel_inicial': litrosAbastecidos,
        'combustivel_final': valorAbastecimento,
        'ocorrencias': ocorrencias,
        'observacoes': observacoes,
        'criado_em': criadoEm?.toIso8601String(),
        'planilha_url': planilhaUrl,
      };

  String toJson() => jsonEncode(toMap());

  factory RegistroServicoModel.fromJson(String source) =>
      RegistroServicoModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

