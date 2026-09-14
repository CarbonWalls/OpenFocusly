import 'package:flutter/widgets.dart';
import '../../theme/theme_scope.dart';
import '../../theme/styles.dart';

class TimeWheel extends StatefulWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final String label;

  const TimeWheel({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.label,
  });

  @override
  State<TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<TimeWheel> {
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 70,
          height: 130,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 40,
            useMagnifier: true,
            magnification: 1.2,
            overAndUnderCenterOpacity: 0.4,
            perspective: 0.005,
            onSelectedItemChanged: (index) => widget.onChanged(index),
            controller: _controller,
            physics: const FixedExtentScrollPhysics(),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.max + 1,
              builder: (context, index) {
                final selected = index == widget.value;
                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: selected ? 24 : 18,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? p.accent : p.text2,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.label, style: cap(p)),
      ],
    );
  }
}
