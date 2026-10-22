import 'dart:math';
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
      child: CustomPaint(
        painter: _QrPainter(data: data, color: darkColor),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final String data;
  final Color color;

  _QrPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const int matrixSize = 25;
    final double cellSize = size.width / matrixSize;

    // Generate pseudo-random matrix based on data hash
    final int seed = data.hashCode.abs();
    final random = Random(seed);

    // Draw finder patterns (top-left, top-right, bottom-left)
    void drawFinderPattern(int startRow, int startCol) {
      // 7x7 outer square
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 7; c++) {
          if (r == 0 || r == 6 || c == 0 || c == 6) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  (startCol + c) * cellSize,
                  (startRow + r) * cellSize,
                  cellSize,
                  cellSize,
                ),
                Radius.circular(cellSize * 0.2),
              ),
              paint,
            );
          } else if (r >= 2 && r <= 4 && c >= 2 && c <= 4) {
            // 3x3 inner square
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  (startCol + c) * cellSize,
                  (startRow + r) * cellSize,
                  cellSize,
                  cellSize,
                ),
                Radius.circular(cellSize * 0.2),
              ),
              paint,
            );
          }
        }
      }
    }

    drawFinderPattern(0, 0);
    drawFinderPattern(0, matrixSize - 7);
    drawFinderPattern(matrixSize - 7, 0);

    // Draw timing patterns
    for (int i = 8; i < matrixSize - 8; i++) {
      if (i % 2 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(6 * cellSize, i * cellSize, cellSize, cellSize),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(i * cellSize, 6 * cellSize, cellSize, cellSize),
          paint,
        );
      }
    }

    // Fill data grid
    for (int r = 0; r < matrixSize; r++) {
      for (int c = 0; c < matrixSize; c++) {
        final bool inTopLeft = r < 8 && c < 8;
        final bool inTopRight = r < 8 && c >= matrixSize - 8;
        final bool inBottomLeft = r >= matrixSize - 8 && c < 8;

        if (!inTopLeft && !inTopRight && !inBottomLeft) {
          if (random.nextDouble() > 0.45) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  c * cellSize + (cellSize * 0.08),
                  r * cellSize + (cellSize * 0.08),
                  cellSize * 0.84,
                  cellSize * 0.84,
                ),
                Radius.circular(cellSize * 0.25),
              ),
              paint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
