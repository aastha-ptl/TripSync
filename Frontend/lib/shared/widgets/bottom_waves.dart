import 'package:flutter/material.dart';

class BottomWaves extends StatelessWidget {
  final double height;

  const BottomWaves({
    super.key,
    this.height = 160.0,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: BottomWavesPainter(),
      ),
    );
  }
}

class BottomWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Wave 1 (Back wave - Lighter blue)
    final paint1 = Paint()
      ..color = const Color(0xFFEBF3FF)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.4);
    path1.cubicTo(
      size.width * 0.25, size.height * 0.1, 
      size.width * 0.55, size.height * 0.85, 
      size.width, size.height * 0.35,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Wave 2 (Middle wave - Soft blue)
    final paint2 = Paint()
      ..color = const Color(0xFFD0E4FF)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.6);
    path2.cubicTo(
      size.width * 0.3, size.height * 0.25, 
      size.width * 0.65, size.height * 0.9, 
      size.width, size.height * 0.45,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);

    // Wave 3 (Front wave - Accent blue)
    final paint3 = Paint()
      ..color = const Color(0xFFB3D4FF)
      ..style = PaintingStyle.fill;

    final path3 = Path();
    path3.moveTo(0, size.height * 0.75);
    path3.cubicTo(
      size.width * 0.35, size.height * 0.45, 
      size.width * 0.7, size.height * 0.95, 
      size.width, size.height * 0.6,
    );
    path3.lineTo(size.width, size.height);
    path3.lineTo(0, size.height);
    path3.close();
    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
