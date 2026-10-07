import 'dart:math' as math;

import 'package:flutter/material.dart';

// Le dossier reprend le rabat clair et le relief doux de la maquette.
class ProjectFolderIcon extends StatelessWidget {
  const ProjectFolderIcon({super.key, required this.color, this.size = 30});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _FolderPainter(color)),
    ),
  );
}

class _FolderPainter extends CustomPainter {
  const _FolderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 32, size.height / 32);
    final back = Path()
      ..moveTo(3, 12)
      ..lineTo(3, 8)
      ..quadraticBezierTo(3, 5, 6, 5)
      ..lineTo(11, 5)
      ..quadraticBezierTo(12.5, 5, 13.5, 6.5)
      ..lineTo(16, 10)
      ..lineTo(26, 10)
      ..quadraticBezierTo(29, 10, 29, 13)
      ..lineTo(29, 24)
      ..lineTo(3, 24)
      ..close();
    canvas.drawPath(
      back,
      Paint()..color = Color.lerp(color, Colors.white, 0.2)!,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5.5, 8, 7, 3.5),
        const Radius.circular(1),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.88),
    );
    final front = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3, 11.5, 26, 17),
      const Radius.circular(2.8),
    );
    canvas.drawRRect(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.32)!, color],
        ).createShader(const Rect.fromLTWH(3, 11.5, 26, 17)),
    );
    canvas.drawRRect(
      front.deflate(0.35),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = Colors.white.withValues(alpha: 0.12),
    );
  }

  @override
  bool shouldRepaint(_FolderPainter oldDelegate) => oldDelegate.color != color;
}

// Le cercle pointille indique In progress sans le confondre avec Done.
class TaskProgressIcon extends StatelessWidget {
  const TaskProgressIcon({super.key, required this.color, this.size = 15});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _ProgressPainter(color)),
    ),
  );
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide * 0.39;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    for (var i = 0; i < 8; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 + i * math.pi / 4,
        math.pi / 9,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) =>
      oldDelegate.color != color;
}
