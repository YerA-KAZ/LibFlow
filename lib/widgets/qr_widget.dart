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
