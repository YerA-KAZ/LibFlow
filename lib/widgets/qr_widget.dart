import 'dart:math';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';

class CustomQrView extends StatelessWidget {
  final String data;
  final double size;
  final Color darkColor;
  final Color lightColor;

  const CustomQrView({
    super.key,
    required this.data,
    this.size = 200,
    this.darkColor = const Color(0xFF0F172A),
    this.lightColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: QrImageView(
        data: data,
        backgroundColor: lightColor,
        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: darkColor),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: darkColor,
        ),
      ),
    );
  }
}

class BarcodeView extends StatelessWidget {
  final String code;
  final double height;

  const BarcodeView({super.key, required this.code, this.height = 50});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomPaint(
          size: Size(240, height),
          painter: _BarcodePainter(code: code),
        ),
        const SizedBox(height: 4),
        Text(
          code,
          style: const TextStyle(
            letterSpacing: 3,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String code;
  _BarcodePainter({required this.code});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final random = Random(code.hashCode.abs());
    double currentX = 0;

    while (currentX < size.width) {
      final double barWidth = (random.nextInt(3) + 1.5);
      final double spaceWidth = (random.nextInt(3) + 1.5);

      if (currentX + barWidth <= size.width) {
        canvas.drawRect(
          Rect.fromLTWH(currentX, 0, barWidth, size.height),
          paint,
        );
      }
      currentX += barWidth + spaceWidth;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
