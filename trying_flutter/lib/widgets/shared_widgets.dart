import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    required this.padding,
    required this.borderRadius,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: onSurface.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class FeatureChip extends StatelessWidget {
  const FeatureChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: onSurface.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: onSurface),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface)),
        ],
      ),
    );
  }
}

class GlowOrb extends StatelessWidget {
  const GlowOrb({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class AnimatedDashboardBackground extends StatelessWidget {
  const AnimatedDashboardBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          const MovingBubblesBackground(),
          Positioned(
            top: -100,
            right: -50,
            child: GlowOrb(
              size: 500,
              color: onSurface.withValues(alpha: 0.015),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: GlowOrb(
              size: 600,
              color: onSurface.withValues(alpha: 0.01),
            ),
          ),
        ],
      ),
    );
  }
}

class MovingBubblesBackground extends StatefulWidget {
  const MovingBubblesBackground({super.key});

  @override
  State<MovingBubblesBackground> createState() => _MovingBubblesBackgroundState();
}

class _MovingBubblesBackgroundState extends State<MovingBubblesBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Bubble> _bubbles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    
    for (int i = 0; i < 40; i++) {
      _bubbles.add(Bubble());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: BubblePainter(_bubbles, _controller.value, onSurface.withValues(alpha: 0.06)),
          size: Size.infinite,
        );
      },
    );
  }
}

class Bubble {
  late double x;
  late int speedFactor;
  late double size;
  late double initialYOffset;

  Bubble() {
    final random = math.Random();
    x = random.nextDouble();
    // Using an integer speed factor ensures perfect looping without jumps
    speedFactor = random.nextInt(3) + 1; 
    size = 2 + random.nextDouble() * 6;
    initialYOffset = random.nextDouble();
  }
}

class BubblePainter extends CustomPainter {
  final List<Bubble> bubbles;
  final double animationValue;
  final Color bubbleColor;

  BubblePainter(this.bubbles, this.animationValue, this.bubbleColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = bubbleColor
      ..style = PaintingStyle.fill;

    for (var bubble in bubbles) {
      // (Initial Offset - Progress) % 1.0 creates continuous upward motion
      double relativeY = (bubble.initialYOffset - (animationValue * bubble.speedFactor)) % 1.0;
      if (relativeY < 0) relativeY += 1.0;
      
      final y = relativeY * size.height;
      final x = bubble.x * size.width;
      
      canvas.drawCircle(Offset(x, y), bubble.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: onSurface.withValues(alpha: 0.4),
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 1.2,
      ),
    );
  }
}

InputDecoration fieldDecoration({
  required Color onSurface,
  required String hintText,
  required IconData prefixIcon,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: TextStyle(fontSize: 15, color: onSurface.withValues(alpha: 0.3)),
    prefixIcon: Icon(prefixIcon, size: 20, color: onSurface.withValues(alpha: 0.5)),
    suffixIcon: suffix,
    filled: true,
    fillColor: onSurface.withValues(alpha: 0.04),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: onSurface.withValues(alpha: 0.2), width: 1.5),
    ),
  );
}

BoxDecoration inputDecoration(Color onSurface) {
  return BoxDecoration(
    color: onSurface.withValues(alpha: 0.04),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: onSurface.withValues(alpha: 0.1)),
  );
}

Future<void> logout(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    // Do NOT remove saved_username and saved_password here, 
    // so they stay remembered for the next time the user opens the app.
    await prefs.setBool('was_logged_out', true);
    
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  } catch (e) {
    debugPrint('Logout error: $e');
  }
}
