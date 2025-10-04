import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/health_controller.dart';

class PerformanceHUD extends StatelessWidget {
  const PerformanceHUD({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HealthController>();

    return Container(
      color: Colors.black.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Obx(() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetric(
            'Avg Build',
            '${controller.avgBuildTime.value.toStringAsFixed(2)}ms',
            controller.avgBuildTime.value <= 8 ? Colors.green : Colors.red,
          ),
          _buildMetric(
            'Paint',
            '${controller.lastPaintTime.value.toStringAsFixed(2)}ms',
            Colors.blue,
          ),
          _buildMetric(
            'FPS',
            controller.fps.value.toStringAsFixed(0),
            controller.fps.value >= 55 ? Colors.green : Colors.orange,
          ),
          _buildMetric(
            'Jank',
            '${controller.jankFrames.value}',
            controller.jankFrames.value == 0 ? Colors.green : Colors.red,
          ),
        ],
      )),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}