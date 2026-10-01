import 'dart:io';

import 'package:flutter/material.dart';

class SeletorFotosWidget extends StatelessWidget {
  final List<File> fotos;
  final bool salvando;
  final VoidCallback onSelecionarCamera;
  final VoidCallback onSelecionarGaleria;
  final Function(int) onRemoverFoto;
  final int maxFotos;

  const SeletorFotosWidget({
    super.key,
    required this.fotos,
    required this.salvando,
    required this.onSelecionarCamera,
    required this.onSelecionarGaleria,
    required this.onRemoverFoto,
    this.maxFotos = 5,
  });

  @override
  Widget build(BuildContext context) {
    final bool limiteAtingido = fotos.length >= maxFotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fotos do problema',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Adicione pelo menos uma foto quando houver uma avaria.'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: salvando || limiteAtingido
                    ? null
                    : onSelecionarCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('CÂMERA'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: salvando || limiteAtingido
                    ? null
                    : onSelecionarGaleria,
                icon: const Icon(Icons.photo_library),
                label: const Text('GALERIA'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (fotos.isNotEmpty)
          SizedBox(
            height: 105,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: fotos.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(fotos[index], fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => onRemoverFoto(index),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
