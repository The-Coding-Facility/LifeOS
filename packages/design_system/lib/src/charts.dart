import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Liniendiagramm für einen Verlauf, z. B. den Kontostand der letzten 30 Tage.
///
/// [values] sind ganze Zahlen (bei Geld: Cent). [formatValue] beschriftet die
/// Achse. [startLabel] und [endLabel] stehen unter dem ersten und letzten
/// Punkt.
class LineChartView extends StatelessWidget {
  const LineChartView({
    super.key,
    required this.values,
    required this.formatValue,
    this.startLabel,
    this.endLabel,
    this.height = 180,
    this.color,
  });

  final List<int> values;
  final String Function(int value) formatValue;
  final String? startLabel;
  final String? endLabel;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text('Noch keine Daten', style: theme.textTheme.bodyMedium)),
      );
    }
    final labelStyle = theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11);
    return Semantics(
      label: 'Verlauf von ${formatValue(values.first)} bis ${formatValue(values.last)}',
      child: SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _LinePainter(
            values: values,
            formatValue: formatValue,
            startLabel: startLabel,
            endLabel: endLabel,
            lineColor: color ?? theme.colorScheme.primary,
            gridColor: theme.colorScheme.outlineVariant,
            labelStyle: labelStyle.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Ein Wert in einem Balken.
class BarValue {
  const BarValue(this.value, this.color);

  final int value;
  final Color color;
}

/// Eine Gruppe nebeneinanderliegender Balken, z. B. ein Monat mit
/// Einnahmen und Ausgaben.
class BarGroup {
  const BarGroup({required this.label, required this.values});

  final String label;
  final List<BarValue> values;
}

/// Balkendiagramm mit Gruppen, z. B. Einnahmen und Ausgaben je Monat.
class BarChartView extends StatelessWidget {
  const BarChartView({
    super.key,
    required this.groups,
    required this.formatValue,
    this.height = 180,
  });

  final List<BarGroup> groups;
  final String Function(int value) formatValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (groups.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text('Noch keine Daten', style: theme.textTheme.bodyMedium)),
      );
    }
    final labelStyle = theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11);
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _BarPainter(
          groups: groups,
          formatValue: formatValue,
          gridColor: theme.colorScheme.outlineVariant,
          labelStyle: labelStyle.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Fortschritt eines Budgets oder Sparziels. Über 100 % wird der Balken rot.
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.value, required this.limit, this.color});

  final int value;
  final int limit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = limit <= 0 ? (value > 0 ? 1.0 : 0.0) : value / limit;
    final over = limit > 0 && value > limit;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0).toDouble(),
        minHeight: 10,
        backgroundColor: scheme.surfaceContainerHighest,
        color: over ? scheme.error : (color ?? scheme.primary),
      ),
    );
  }
}

const double _axisWidth = 64;
const double _bottomLabelHeight = 18;

TextPainter _text(String text, TextStyle style) =>
    TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)
      ..layout();

({int low, int high}) _range(Iterable<int> values) {
  var low = values.fold<int>(0, math.min);
  var high = values.fold<int>(0, math.max);
  if (low == high) {
    high = low + 100;
  }
  return (low: low, high: high);
}

void _drawGrid(
  Canvas canvas,
  Rect plot,
  ({int low, int high}) range,
  String Function(int) format,
  Color gridColor,
  TextStyle style,
) {
  final grid = Paint()
    ..color = gridColor
    ..strokeWidth = 1;
  for (var step = 0; step <= 2; step++) {
    final value = range.low + (range.high - range.low) * step ~/ 2;
    final y = plot.bottom - plot.height * step / 2;
    canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    final label = _text(format(value), style);
    label.paint(canvas, Offset(plot.left - label.width - 6, y - label.height / 2));
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.formatValue,
    required this.startLabel,
    required this.endLabel,
    required this.lineColor,
    required this.gridColor,
    required this.labelStyle,
  });

  final List<int> values;
  final String Function(int) formatValue;
  final String? startLabel;
  final String? endLabel;
  final Color lineColor;
  final Color gridColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= _axisWidth + 8 || size.height <= _bottomLabelHeight + 8) return;
    final plot = Rect.fromLTRB(_axisWidth, 6, size.width - 4, size.height - _bottomLabelHeight);
    final range = _range(values);
    _drawGrid(canvas, plot, range, formatValue, gridColor, labelStyle);

    double yOf(int value) =>
        plot.bottom - (value - range.low) / (range.high - range.low) * plot.height;
    double xOf(int index) =>
        values.length == 1 ? plot.center.dx : plot.left + plot.width * index / (values.length - 1);

    final line = Path()..moveTo(xOf(0), yOf(values.first));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(xOf(i), yOf(values[i]));
    }
    final area = Path.from(line)
      ..lineTo(xOf(values.length - 1), plot.bottom)
      ..lineTo(xOf(0), plot.bottom)
      ..close();
    canvas.drawPath(area, Paint()..color = lineColor.withValues(alpha: 0.12));
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(xOf(values.length - 1), yOf(values.last)), 4, Paint()..color = lineColor);

    if (startLabel != null) {
      _text(startLabel!, labelStyle).paint(canvas, Offset(plot.left, plot.bottom + 3));
    }
    if (endLabel != null) {
      final label = _text(endLabel!, labelStyle);
      label.paint(canvas, Offset(plot.right - label.width, plot.bottom + 3));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.lineColor != lineColor || old.labelStyle != labelStyle;
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.groups,
    required this.formatValue,
    required this.gridColor,
    required this.labelStyle,
  });

  final List<BarGroup> groups;
  final String Function(int) formatValue;
  final Color gridColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= _axisWidth + 8 || size.height <= _bottomLabelHeight + 8) return;
    final plot = Rect.fromLTRB(_axisWidth, 6, size.width - 4, size.height - _bottomLabelHeight);
    final range = _range([for (final group in groups) for (final bar in group.values) bar.value]);
    _drawGrid(canvas, plot, range, formatValue, gridColor, labelStyle);

    double yOf(int value) =>
        plot.bottom - (value - range.low) / (range.high - range.low) * plot.height;
    final zero = yOf(0);
    final slot = plot.width / groups.length;
    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      final count = math.max(group.values.length, 1);
      final barWidth = math.max(2.0, slot * 0.7 / count);
      final left = plot.left + slot * g + (slot - barWidth * count) / 2;
      for (var b = 0; b < group.values.length; b++) {
        final bar = group.values[b];
        final top = yOf(bar.value);
        final rect = Rect.fromLTRB(
          left + barWidth * b,
          math.min(top, zero),
          left + barWidth * (b + 1) - 1,
          math.max(top, zero),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = bar.color,
        );
      }
      final label = _text(group.label, labelStyle);
      if (label.width <= slot + 4) {
        label.paint(canvas, Offset(plot.left + slot * g + (slot - label.width) / 2, plot.bottom + 3));
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.groups != groups || old.labelStyle != labelStyle;
}
