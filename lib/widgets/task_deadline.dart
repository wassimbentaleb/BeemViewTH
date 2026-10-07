import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/date_formatter.dart';
import '../core/deadline_countdown.dart';
import '../models/task.dart';

// Le delai se met a jour a minuit et au retour dans l'app, sans appel HTTP.
class TaskDeadline extends StatefulWidget {
  const TaskDeadline({super.key, required this.task, this.now});

  final Task task;
  // Une date fixe permet des apercus et tests independants de l'horloge du PC.
  final DateTime? now;

  @override
  State<TaskDeadline> createState() => _TaskDeadlineState();
}

class _TaskDeadlineState extends State<TaskDeadline>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Timer? _attentionTimer;
  Timer? _midnightTimer;
  bool _canAnimate = false;
  bool _foreground = true;

  DeadlineCountdown get _countdown => DeadlineCountdown.at(
    widget.task.dueDate,
    now: widget.now ?? DateTime.now(),
    inactive: widget.task.status == 'done' || widget.task.status == 'canceled',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _scheduleMidnight();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAttention();
  }

  @override
  void didUpdateWidget(TaskDeadline oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMidnight();
    _updateAttention();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      setState(() {});
      _scheduleMidnight();
    } else {
      _midnightTimer?.cancel();
    }
    _updateAttention();
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    if (widget.now != null || widget.task.dueDate == null || !_foreground) {
      return;
    }
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(midnight.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleMidnight();
      _updateAttention();
    });
  }

  void _updateAttention() {
    final enabled =
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        _countdown.needsAttention;
    if (enabled == _canAnimate) return;
    _canAnimate = enabled;
    _attentionTimer?.cancel();
    _pulse.stop();
    _pulse.value = 0;
    if (enabled) {
      // Laisse finir l'entree de la carte, puis rappelle le delai toutes les 12 s.
      _scheduleAttention(const Duration(milliseconds: 600));
    }
  }

  void _scheduleAttention(Duration delay) {
    _attentionTimer = Timer(delay, () {
      if (!mounted || !_canAnimate) return;
      _pulse.forward(from: 0);
      _scheduleAttention(const Duration(seconds: 12));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attentionTimer?.cancel();
    _midnightTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _countdown;
    final colors = AppColors.of(context);
    final color = colors.muted;
    final dueDate = widget.task.dueDate;
    final semantics = dueDate == null
        ? 'No due date'
        : '${countdown.label}. Due date ${DateFormatter.date(dueDate)}';
    return Tooltip(
      message: dueDate == null ? 'No due date' : DateFormatter.date(dueDate),
      excludeFromSemantics: true,
      child: Semantics(
        label: semantics,
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final pulse = _canAnimate
                  ? math.sin(_pulse.value * math.pi)
                  : 0.0;
              return Transform.scale(
                scale: 1 + 0.035 * pulse,
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        countdown.days != null && countdown.days! < 0
                            ? Icons.history_rounded
                            : Icons.schedule_rounded,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          countdown.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
