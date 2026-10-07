import 'package:flutter/material.dart';

// Les interactions courtes partagent leurs durees et la preference d'accessibilite.
class AppMotion {
  static const quick = Duration(milliseconds: 180);
  static const press = Duration(milliseconds: 100);
  static const standard = Duration(milliseconds: 220);
  static const success = Duration(milliseconds: 240);

  static Duration duration(BuildContext context, {Duration value = standard}) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}

// Listener laisse le bouton Material gerer clic, focus, ripple et semantique.
class AppPressScale extends StatefulWidget {
  const AppPressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<AppPressScale> createState() => _AppPressScaleState();
}

class _AppPressScaleState extends State<AppPressScale> {
  final _pointers = <int>{};
  bool _pressed = false;
  bool _pressSettled = false;

  void _release(int pointer, {bool cancelled = false}) {
    if (_pointers.remove(pointer)) {
      setState(() {
        // Un tap rapide garde son feedback sans retarder l'action du bouton.
        if (_pointers.isEmpty && (_pressSettled || cancelled)) _pressed = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pointers.clear();
      _pressed = false;
    }
  }

  @override
  void didUpdateWidget(AppPressScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _pointers.clear();
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final pressed = widget.enabled && !reduced && _pressed;
    return Listener(
      onPointerDown: (event) {
        if (widget.enabled && !reduced) {
          setState(() {
            if (!_pressed) {
              _pressed = true;
              _pressSettled = false;
            }
            _pointers.add(event.pointer);
          });
        }
      },
      onPointerUp: (event) => _release(event.pointer),
      onPointerCancel: (event) => _release(event.pointer, cancelled: true),
      child: AnimatedScale(
        scale: pressed ? 0.96 : 1,
        duration: AppMotion.duration(
          context,
          value: pressed ? AppMotion.press : AppMotion.quick,
        ),
        curve: Curves.easeOutCubic,
        onEnd: () {
          if (_pressed && !_pressSettled) {
            setState(() {
              _pressSettled = true;
              if (_pointers.isEmpty) _pressed = false;
            });
          }
        },
        child: widget.child,
      ),
    );
  }
}

// Un seul resultat reste interactif; une nouvelle saisie remplace le fade en cours.
class AppResultFade extends StatefulWidget {
  const AppResultFade({super.key, required this.revision, required this.child});

  final Object revision;
  final Widget child;

  @override
  State<AppResultFade> createState() => _AppResultFadeState();
}

class _AppResultFadeState extends State<AppResultFade>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.quick,
    value: 1,
  );
  late final _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(AppResultFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_reduced && oldWidget.revision != widget.revision) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

// La route peut se fermer a la fin du dessin, sans timer ni nouvelle ecriture.
class AppSuccessCheck extends StatefulWidget {
  const AppSuccessCheck({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<AppSuccessCheck> createState() => _AppSuccessCheckState();
}

class _AppSuccessCheckState extends State<AppSuccessCheck>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: AppMotion.success)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _complete();
        });
  bool _started = false;
  bool _completed = false;

  void _complete() {
    if (_completed) return;
    _completed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCompleted();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_started && !_completed) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(_controller.value);
        return Transform.scale(
          scale: 0.88 + 0.12 * progress,
          child: CustomPaint(
            size: const Size.square(24),
            painter: _CheckPainter(
              progress,
              IconTheme.of(context).color ??
                  Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        );
      },
    ),
  );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.51)
      ..lineTo(size.width * 0.41, size.height * 0.74)
      ..lineTo(size.width * 0.83, size.height * 0.26);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
