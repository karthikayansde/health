import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/health_controller.dart';
import '../widgets/health_chart.dart';
import '../widgets/performance_hud.dart';
import '../models/health_data_point.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HealthController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Get.toNamed('/debug'),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildLiveDataCards(controller),
              const SizedBox(height: 24),
              _buildStepsChart(controller),
              const SizedBox(height: 24),
              _buildHeartRateChart(controller),
              const SizedBox(height: 80),
            ],
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: PerformanceHUD(),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDataCards(HealthController controller) {
    return Row(
      children: [
        Expanded(
          child: Obx(
            () => _buildStatCard(
              'Steps Today',
              controller.currentSteps.value.toString(),
              Icons.directions_walk,
              Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Obx(() {
            final hr = controller.currentHeartRate.value;
            final timestamp = controller.lastHRTimestamp.value;
            final age = timestamp != null ? _getAge(timestamp) : 'No data';

            return _buildStatCard(
              'Heart Rate',
              hr > 0 ? '$hr BPM' : '--',
              Icons.favorite,
              Colors.red,
              subtitle: age,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepsChart(HealthController controller) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Steps Timeline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Obx(
                  () => DropdownButton<int>(
                    value: controller.stepsWindowMinutes.value,
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('30 min')),
                      DropdownMenuItem(value: 60, child: Text('60 min')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.setStepsWindow(value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Obx(() {
              final data = List<HealthDataPoint>.from(
                controller.decimatedSteps,
              );
              return SizedBox(
                height: 200,
                child: HealthChart(
                  data: data,
                  color: Colors.blue,
                  label: 'Steps',
                  onPaintComplete: (ms) => controller.recordPaintTime(ms),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateChart(HealthController controller) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Heart Rate Timeline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Obx(
                  () => Row(
                    children: [
                      const Text('Smooth'),
                      Switch(
                        value: controller.hrSmoothingEnabled.value,
                        onChanged: (_) => controller.toggleHRSmoothing(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Obx(() {
              final data = List<HealthDataPoint>.from(
                controller.decimatedHeartRate,
              );
              return SizedBox(
                height: 200,
                child: HealthChart(
                  data: data,
                  color: Colors.red,
                  label: 'BPM',
                  onPaintComplete: (ms) => controller.recordPaintTime(ms),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getAge(DateTime timestamp) {
    final duration = DateTime.now().difference(timestamp);

    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s ago';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ago';
    } else {
      return '${duration.inHours}h ago';
    }
  }
}
