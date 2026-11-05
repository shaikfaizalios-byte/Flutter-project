import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// False keeps the icon still whatever the system says (widget tests, which wait for
/// animations to end).
final ladderIconMotionProvider = Provider<bool>((ref) => true);

/// Step colours, bottom to top. Fixed on purpose: they read as easy to hard on any theme.
const ladderStepColors = [
  Color(0xFF2E9E5B),
  Color(0xFF2E9E5B),
  Color(0xFFF2A81D),
  Color(0xFFEF7A1A),
  Color(0xFFD93A2B),
];

/// Five rising steps with a small flame on the top one, drawn as a vector so it scales and works
/// in dark mode. The steps light up in turn, then the top step pulses gently. With the system's
/// reduce-motion setting it stays still, fully lit.
class LadderIcon extends ConsumerStatefulWidget {
  const LadderIcon({super.key, this.size = 56});

  final double size;

  @override
  ConsumerState<LadderIcon> createState() => _LadderIconState();
}

class _LadderIconState extends ConsumerState<LadderIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  bool get _still => MediaQuery.disableAnimationsOf(context) || !ref.read(ladderIconMotionProvider);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: LadderIconPainter(progress: _still ? 1 : _controller.value, dim: dim),
          ),
        ),
      ),
    );
  }
}

/// [progress] 0-1 is one cycle: the first half lights the steps, the rest pulses the top.
class LadderIconPainter extends CustomPainter {
  const LadderIconPainter({required this.progress, required this.dim});

  final double progress;
  final Color dim;

  static const _steps = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width * 0.04;
    final width = (size.width - gap * (_steps - 1)) / _steps;
    final flame = size.height * 0.26;
    final tallest = size.height - flame;
    final lit = (progress * 2 * _steps).clamp(0, _steps).toDouble();
    final pulse = progress < 0.5 ? 0.0 : (math.sin((progress - 0.5) * 4 * math.pi) + 1) / 2;

    for (var i = 0; i < _steps; i++) {
      final height = tallest * (i + 1) / _steps;
      final left = i * (width + gap);
      final on = (lit - i).clamp(0.0, 1.0);
      final rect = Rect.fromLTWH(left, size.height - height, width, height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(width * 0.2)),
        Paint()..color = Color.lerp(dim, ladderStepColors[i], on)!,
      );
    }
    if (lit < _steps) return;

    final centre = Offset(size.width - width / 2, flame * 0.55);
    final radius = flame * (0.5 + 0.08 * pulse);
    canvas.drawCircle(
      centre,
      radius * 1.5,
      Paint()
        ..color = const Color(0xFFFFB347).withValues(alpha: 0.18 + 0.2 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.6),
    );
    final path = Path()
      ..moveTo(centre.dx, centre.dy - radius)
      ..quadraticBezierTo(
        centre.dx + radius * 0.95,
        centre.dy + radius * 0.1,
        centre.dx,
        centre.dy + radius * 0.8,
      )
      ..quadraticBezierTo(
        centre.dx - radius * 0.95,
        centre.dy + radius * 0.1,
        centre.dx,
        centre.dy - radius,
      );
    canvas.drawPath(path, Paint()..color = const Color(0xFFFF8A1F));
  }

  @override
  bool shouldRepaint(LadderIconPainter old) => old.progress != progress || old.dim != dim;
}
