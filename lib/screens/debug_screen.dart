import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:math';
import '../services/health_connect_service.dart';
import '../controllers/health_controller.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final HealthConnectService _healthService = Get.find();
  final HealthController _healthController = Get.find();
  Timer? _simTimer;
  final Random _random = Random();

  @override
  void dispose() {
    _stopSimulation();
    super.dispose();
  }

  void _startSimulation() {
    _healthService.enableSimMode();

    var stepCount = 0;
    var heartRate = 70.0;

    _simTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      // Simulate steps increment
      stepCount += _random.nextInt(20) + 5;
      _healthService.emitSimData('STEPS', stepCount.toDouble());

      // Simulate heart rate variation
      heartRate += (_random.nextDouble() - 0.5) * 10;
      heartRate = heartRate.clamp(60, 180);
      _healthService.emitSimData('HEART_RATE', heartRate);
    });

    setState(() {});
  }

  void _stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    _healthService.disableSimMode();
    setState(() {});
  }

  void _sendSingleUpdate(String type) {
    _healthService.enableSimMode();

    if (type == 'STEPS') {
      final steps = _random.nextInt(1000) + 500;
      _healthService.emitSimData('STEPS', steps.toDouble());
    } else {
      final hr = _random.nextInt(60) + 60;
      _healthService.emitSimData('HEART_RATE', hr.toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug & Testing'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Simulation Source',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enable synthetic data generation for testing without Health Connect.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Obx(() => SwitchListTile(
            title: const Text('SimSource Enabled'),
            subtitle: Text(
              _healthService.isSimMode.value
                  ? 'Using synthetic data'
                  : 'Using Health Connect',
            ),
            value: _healthService.isSimMode.value,
            onChanged: (value) {
              if (value) {
                _startSimulation();
              } else {
                _stopSimulation();
              }
            },
          )),
          if (_healthService.isSimMode.value) ...[
            const Divider(height: 32),
            const Text(
              'Manual Data Injection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendSingleUpdate('STEPS'),
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('Send Steps'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sendSingleUpdate('HEART_RATE'),
                    icon: const Icon(Icons.favorite),
                    label: const Text('Send HR'),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 32),
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() => _buildMetricCard(
            'Average Build Time',
            '${_healthController.avgBuildTime.value.toStringAsFixed(2)} ms',
            _healthController.avgBuildTime.value <= 8,
            'Target: ≤ 8ms',
          )),
          const SizedBox(height: 8),
          Obx(() => _buildMetricCard(
            'Last Paint Time',
            '${_healthController.lastPaintTime.value.toStringAsFixed(2)} ms',
            true,
            'Lower is better',
          )),
          // const SizedBox(height: 8),
          // Obx(() => _buildMetricCard(
          //   'FPS Estimate',
          //   _healthController.fps.value.toStringAsFixed(0),
          //   _healthController.fps.value >= 55,
          //   'Target: 60 FPS',
          // )),
          const SizedBox(height: 8),
          Obx(() => _buildMetricCard(
            'Jank Frames',
            '${_healthController.jankFrames.value}',
            _healthController.jankFrames.value == 0,
            'Target: 0 frames',
          )),
          const Divider(height: 32),
          const Text(
            'Data Statistics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() => _buildStatCard(
            'Steps Data Points',
            '${_healthController.stepsHistory.length} raw / ${_healthController.decimatedSteps.length} decimated',
          )),
          const SizedBox(height: 8),
          Obx(() => _buildStatCard(
            'Heart Rate Data Points',
            '${_healthController.heartRateHistory.length} raw / ${_healthController.decimatedHeartRate.length} decimated',
          )),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Get.back(),
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title,
      String value,
      bool isGood,
      String target,
      ) {
    return Card(
      color: isGood ? Colors.green.shade50 : Colors.red.shade50,
      child: ListTile(
        leading: Icon(
          isGood ? Icons.check_circle : Icons.warning,
          color: isGood ? Colors.green : Colors.red,
        ),
        title: Text(title),
        subtitle: Text(target),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isGood ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}