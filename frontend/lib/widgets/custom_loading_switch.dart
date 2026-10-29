import 'dart:math' as math;
import 'package:flutter/material.dart';

class CustomLoadingSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const CustomLoadingSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = Colors.deepOrange,
  });

  @override
  State<CustomLoadingSwitch> createState() => _CustomLoadingSwitchState();
}

class _CustomLoadingSwitchState extends State<CustomLoadingSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.value ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(CustomLoadingSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          final progress = _animController.value;
          return Container(
            width: 52,
            height: 28,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Color.lerp(Colors.grey[800], widget.activeColor, progress),
            ),
            child: Align(
              alignment: AlignmentTween(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).evaluate(_animController),
              child: Transform.rotate(
                angle: progress * 2 * math.pi, // Rolling animation during toggle
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Image.asset(
                    'assets/loading_icon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.fitness_center,
                      size: 14,
                      color: Colors.deepOrange,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}