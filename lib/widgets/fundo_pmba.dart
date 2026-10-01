import 'package:flutter/material.dart';

class FundoPMBA extends StatelessWidget {
  final Widget child;

  const FundoPMBA({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1513), Color(0xFF2E1C1A), Color(0xFF1A1513)],
            ),
          ),
        ),
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF003882).withValues(alpha: 0.10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF003882).withValues(alpha: 0.15),
                  blurRadius: 100,
                  spreadRadius: 100,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFCE181E).withValues(alpha: 0.08),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFCE181E).withValues(alpha: 0.12),
                  blurRadius: 100,
                  spreadRadius: 100,
                ),
              ],
            ),
          ),
        ),
        SafeArea(child: child),
      ],
    );
  }
}
