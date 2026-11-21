import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Modelo de dados imutável representando um item individual do Checklist.
@immutable
class ChecklistItemModel {
  final String item;
  final String status;
  final String observacao;

  const ChecklistItemModel({
    required this.item,
    required this.status,
    this.observacao = '',
  });

  bool get isOk => status.toUpperCase() == 'OK';

  factory ChecklistItemModel.fromMap(Map<String, dynamic> map) {
    return ChecklistItemModel(
      item: (map['item'] as String?)?.trim() ?? '',
      status: (map['status'] as String?)?.trim().toUpperCase() ?? 'OK',
      observacao: (map['observacao'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'item': item,
        'status': status,
        'observacao': observacao,
      };
}

/// Modelo de dados imutável representando um Checklist completo de Viatura.
@immutable
class ChecklistViaturaModel {
  final int id;
  final int viaturaId;
  final String policialMatricula;
  final double km;
  final String status;
  final String tipo;
  final String observacao;
  final DateTime? dataChecklist;
  final List<ChecklistItemModel> itens;
  final List<String> fotos;

  const ChecklistViaturaModel({
    required this.id,
    required this.viaturaId,
    required this.policialMatricula,
    required this.km,
    required this.status,
    this.tipo = 'SAIDA',
    this.observacao = '',
    this.dataChecklist,
    this.itens = const [],
    this.fotos = const [],
  });

  bool get temProblema => status.toUpperCase() == 'PROBLEMA';
  bool get isRetorno => tipo.toUpperCase() == 'RETORNO';

  factory ChecklistViaturaModel.fromMap(Map<String, dynamic> map) {
    final rawItens = map['itens'];
    final listaItens = <ChecklistItemModel>[];
    if (rawItens is List) {
      for (final item in rawItens) {
        if (item is Map<String, dynamic>) {
          listaItens.add(ChecklistItemModel.fromMap(item));
        } else if (item is Map) {
          listaItens.add(ChecklistItemModel.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final rawFotos = map['fotos'];
    final listaFotos = <String>[];
    if (rawFotos is List) {
      for (final f in rawFotos) {
        if (f is Map) {
          final urlFoto = (f['url'] ?? f['foto'])?.toString().trim() ?? '';
          if (urlFoto.isNotEmpty) {
            listaFotos.add(urlFoto);
          }
        } else if (f != null && f.toString().trim().isNotEmpty) {
          listaFotos.add(f.toString().trim());
        }
      }
    }

    final tipoBruto = (map['tipo'] as String?)?.trim().toUpperCase();
    final tipoNormalizado = (tipoBruto == null || tipoBruto.isEmpty) ? 'SAIDA' : tipoBruto;

    return ChecklistViaturaModel(
      id: int.tryParse(map['id']?.toString() ?? '') ?? 0,
      viaturaId: int.tryParse(map['viatura_id']?.toString() ?? '') ?? 0,
      policialMatricula: (map['policial_matricula'] as String?)?.trim() ?? '',
      km: double.tryParse(map['km']?.toString() ?? '') ?? 0.0,
      status: (map['status'] as String?)?.trim().toUpperCase() ?? 'OK',
      tipo: tipoNormalizado,
      observacao: (map['observacao'] as String?)?.trim() ?? '',
      dataChecklist: DateTime.tryParse(map['data_checklist']?.toString() ?? ''),
      itens: listaItens,
      fotos: listaFotos,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'viatura_id': viaturaId,
        'policial_matricula': policialMatricula,
        'km': km,
        'status': status,
        'tipo': tipo,
        'observacao': observacao,
        'data_checklist': dataChecklist?.toIso8601String(),
        'itens': itens.map((e) => e.toMap()).toList(),
        'fotos': fotos,
      };

  String toJson() => jsonEncode(toMap());

  factory ChecklistViaturaModel.fromJson(String source) =>
      ChecklistViaturaModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

