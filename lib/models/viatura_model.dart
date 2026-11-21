import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Modelo de dados imutável representando uma Viatura da frota.
@immutable
class ViaturaModel {
  final int id;
  final String prefixo;
  final String placa;
  final String chassi;
  final String marca;
  final String modelo;
  final String tipo;
  final int anoFabricacao;
  final double kmAtual;
  final double kmProximaManutencao;
  final String status;
  final bool ativo;
  final String observacoes;
  final double kmRestanteManutencao;

  const ViaturaModel({
    required this.id,
    required this.prefixo,
    required this.placa,
    this.chassi = '',
    this.marca = '',
    this.modelo = '',
    this.tipo = 'CARRO',
    this.anoFabricacao = 0,
    this.kmAtual = 0.0,
    this.kmProximaManutencao = 10000.0,
    this.status = 'DISPONÍVEL',
    this.ativo = true,
    this.observacoes = '',
    this.kmRestanteManutencao = 0.0,
  });

  /// Descrição composta formatada para exibição em seletores e títulos.
  String get tituloExibicao {
    if (placa.isEmpty) {
      return prefixo.isEmpty ? 'Viatura sem identificação' : prefixo;
    }
    return prefixo.isEmpty ? placa : '$prefixo • $placa';
  }

  /// Indica se a viatura necessita de manutenção preventiva próxima ou atrasada.
  bool get manutencaoProxima => kmRestanteManutencao <= 1000;

  /// Situação de manutenção calculada: VENCIDA, PROXIMA ou NORMAL.
  String get situacaoManutencao {
    if (kmRestanteManutencao <= 0) return 'VENCIDA';
    if (kmRestanteManutencao <= 1000) return 'PROXIMA';
    return 'NORMAL';
  }

  factory ViaturaModel.fromMap(Map<String, dynamic> map) {
    final kmAtualVal = double.tryParse(map['km_atual']?.toString() ?? '') ?? 0.0;
    final kmManutencaoVal =
        double.tryParse(map['km_proxima_manutencao']?.toString() ?? '') ?? 10000.0;
    final restanteCalc =
        double.tryParse(map['km_restante']?.toString() ??
                map['km_restante_manutencao']?.toString() ??
                '') ??
            (kmManutencaoVal - kmAtualVal);

    return ViaturaModel(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      prefixo: (map['prefixo'] as String?)?.trim() ?? '',
      placa: (map['placa'] as String?)?.trim() ?? '',
      chassi: (map['chassi'] as String?)?.trim() ?? '',
      marca: (map['marca'] as String?)?.trim() ?? '',
      modelo: (map['modelo'] as String?)?.trim() ?? '',
      tipo: (map['tipo'] as String?)?.trim().toUpperCase() ?? 'CARRO',
      anoFabricacao: int.tryParse(map['ano_fabricacao']?.toString() ?? '') ?? 0,
      kmAtual: kmAtualVal,
      kmProximaManutencao: kmManutencaoVal,
      status: (map['status'] as String?)?.trim().toUpperCase() ?? 'DISPONÍVEL',
      ativo: map['ativo'] == true || map['ativo']?.toString() == 'true',
      observacoes: (map['observacoes'] ?? map['observacao'])?.toString().trim() ?? '',
      kmRestanteManutencao: restanteCalc,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'prefixo': prefixo,
        'placa': placa,
        'chassi': chassi,
        'marca': marca,
        'modelo': modelo,
        'tipo': tipo,
        'ano_fabricacao': anoFabricacao,
        'km_atual': kmAtual,
        'km_proxima_manutencao': kmProximaManutencao,
        'status': status,
        'ativo': ativo,
        'observacoes': observacoes,
        'km_restante_manutencao': kmRestanteManutencao,
      };

  String toJson() => jsonEncode(toMap());

  factory ViaturaModel.fromJson(String source) =>
      ViaturaModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

