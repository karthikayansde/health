import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/health_data_point.dart';
import 'dart:math' as math;

class HealthChart extends StatefulWidget {
  final List<HealthDataPoint> data;
  final Color color;
  final String label;
  final Function(double)? onPaintComplete;

  const HealthChart({
    super.key,
    required this.data,
    required this.color,
    required this.label,
    this.onPaintComplete,
  });

  @override
  State<HealthChart> createState() => _HealthChartState();
}

class _HealthChartState extends State<HealthChart> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  Offset? _tooltipPosition;
  HealthDataPoint? _tooltipData;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return Center(
        child: Text(
          'No ${widget.label} data available',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return GestureDetector(
      onScaleStart: (details) {
        _tooltipPosition = null;
        _tooltipData = null;
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_scale * details.scale).clamp(0.5, 3.0);
          _offset += details.focalPointDelta;
        });
      },
      onTapDown: (details) {
        _showTooltip(details.localPosition);
      },
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: ChartPainter(
              data: widget.data,
              color: widget.color,
              scale: _scale,
              offset: _offset,
              onPaintComplete: widget.onPaintComplete,
            ),
          ),
          if (_tooltipPosition != null && _tooltipData != null)
            Positioned(
              left: _tooltipPosition!.dx,
              top: _tooltipPosition!.dy,
              child: _buildTooltip(),
            ),
        ],
      ),
    );
  }

  void _showTooltip(Offset position) {
    if (widget.data.isEmpty) return;

    // Find nearest data point
    final painter = ChartPainter(
      data: widget.data,
      color: widget.color,
      scale: _scale,
      offset: _offset,
    );

    HealthDataPoint? nearest;
    double minDistance = double.infinity;

    for (var point in widget.data) {
      final pointPos = painter.getPointPosition(point, Size(300, 200));
      final distance = (pointPos - position).distance;

      if (distance < minDistance && distance < 50) {
        minDistance = distance;
        nearest = point;
      }
    }

    if (nearest != null) {
      setState(() {
        _tooltipData = nearest;
        _tooltipPosition = position;
      });
    }
  }

  Widget _buildTooltip() {
    if (_tooltipData == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.label}: ${_tooltipData!.value.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            DateFormat('HH:mm:ss').format(_tooltipData!.timestamp),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<HealthDataPoint> data;
  final Color color;
  final double scale;
  final Offset offset;
  final Function(double)? onPaintComplete;

  // Pre-allocated objects to avoid per-frame allocations
  final Paint _linePaint;
  final Paint _pointPaint;
  final Paint _gridPaint;
  final Paint _axisPaint;
  final Path _path = Path();

  ChartPainter({
    required this.data,
    required this.color,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.onPaintComplete,
  })  : _linePaint = Paint()
    ..color = color
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round,
        _pointPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill,
        _gridPaint = Paint()
          ..color = Colors.grey.withOpacity(0.2)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
        _axisPaint = Paint()
          ..color = Colors.grey.withOpacity(0.5)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final startTime = DateTime.now();

    if (data.isEmpty) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Apply transformations
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale, 1.0);

    // Calculate bounds
    final minValue = data.map((p) => p.value).reduce(math.min);
    final maxValue = data.map((p) => p.value).reduce(math.max);
    final valueRange = maxValue - minValue;
    final padding = valueRange * 0.1;

    final minTime = data.first.timestamp.millisecondsSinceEpoch;
    final maxTime = data.last.timestamp.millisecondsSinceEpoch;
    final timeRange = maxTime - minTime;

    // Draw grid
    _drawGrid(canvas, size);

    // Draw chart line
    _path.reset();
    bool firstPoint = true;

    for (var point in data) {
      final x = ((point.timestamp.millisecondsSinceEpoch - minTime) / timeRange) *
          (size.width - 40) +
          20;
      final y = size.height -
          20 -
          ((point.value - minValue + padding) / (valueRange + 2 * padding)) *
              (size.height - 40);

      if (firstPoint) {
        _path.moveTo(x, y);
        firstPoint = false;
      } else {
        _path.lineTo(x, y);
      }
    }

    canvas.drawPath(_path, _linePaint);

    // Draw points (only if not too many)
    if (data.length < 100) {
      for (var point in data) {
        final x = ((point.timestamp.millisecondsSinceEpoch - minTime) / timeRange) *
            (size.width - 40) +
            20;
        final y = size.height -
            20 -
            ((point.value - minValue + padding) / (valueRange + 2 * padding)) *
                (size.height - 40);

        canvas.drawCircle(Offset(x, y), 3, _pointPaint);
      }
    }

    canvas.restore();

    // Record paint time
    if (onPaintComplete != null) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMicroseconds / 1000.0;
      onPaintComplete!(duration);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    // Horizontal grid lines
    for (var i = 0; i < 5; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        _gridPaint,
      );
    }

    // Vertical grid lines
    for (var i = 0; i < 6; i++) {
      final x = (size.width / 5) * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        _gridPaint,
      );
    }
  }

  Offset getPointPosition(HealthDataPoint point, Size size) {
    if (data.isEmpty) return Offset.zero;

    final minValue = data.map((p) => p.value).reduce(math.min);
    final maxValue = data.map((p) => p.value).reduce(math.max);
    final valueRange = maxValue - minValue;
    final padding = valueRange * 0.1;

    final minTime = data.first.timestamp.millisecondsSinceEpoch;
    final maxTime = data.last.timestamp.millisecondsSinceEpoch;
    final timeRange = maxTime - minTime;

    final x = ((point.timestamp.millisecondsSinceEpoch - minTime) / timeRange) *
        (size.width - 40) +
        20;
    final y = size.height -
        20 -
        ((point.value - minValue + padding) / (valueRange + 2 * padding)) *
            (size.height - 40);

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(ChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.scale != scale ||
        oldDelegate.offset != offset;
  }
}