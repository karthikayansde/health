import 'dart:async';
import 'package:get/get.dart';
import '../models/health_data_point.dart';
import '../services/health_connect_service.dart';
import '../utils/decimation.dart';

class HealthController extends GetxController {
  final HealthConnectService _healthService = Get.find();

  // Live data
  final currentSteps = 0.obs;
  final currentHeartRate = 0.obs;
  final lastHRTimestamp = Rx<DateTime?>(null);

  // Historical data (raw)
  final stepsHistory = <HealthDataPoint>[].obs;
  final heartRateHistory = <HealthDataPoint>[].obs;

  // Decimated data for charts
  final decimatedSteps = <HealthDataPoint>[].obs;
  final decimatedHeartRate = <HealthDataPoint>[].obs;

  // Performance metrics
  final avgBuildTime = 0.0.obs;
  final lastPaintTime = 0.0.obs;
  final fps = 0.0.obs;
  final jankFrames = 0.obs;

  final _buildTimes = <double>[];
  Timer? _metricsTimer;

  // Chart settings
  final stepsWindowMinutes = 60.obs;
  final hrSmoothingEnabled = false.obs;

  StreamSubscription? _dataSubscription;

  @override
  void onInit() {
    super.onInit();
    _subscribeToHealthData();
    _startMetricsCollection();
  }

  void _subscribeToHealthData() {
    _dataSubscription = _healthService.dataStream.listen((data) {
      // Debug log: show incoming simulated or real data
      print(
        'HealthController received data: type=${data.type}, value=${data.value}, ts=${data.timestamp}',
      );
      _processHealthData(data);
    });
  }

  void _processHealthData(HealthDataPoint data) {
    if (data.type == 'STEPS') {
      _processStepsData(data);
    } else if (data.type == 'HEART_RATE') {
      _processHeartRateData(data);
    }
  }

  void _processStepsData(HealthDataPoint data) {
    // Update live total
    currentSteps.value = data.value.toInt();

    // Add to history
    stepsHistory.add(data);

    // Keep only data within window
    final cutoff = DateTime.now().subtract(
      Duration(minutes: stepsWindowMinutes.value),
    );
    stepsHistory.removeWhere((p) => p.timestamp.isBefore(cutoff));

    // Decimate for chart
    _decimateStepsData();
  }

  void _processHeartRateData(HealthDataPoint data) {
    print('Processing heart rate: ${data.value} at ${data.timestamp}');
    // Update live value
    currentHeartRate.value = data.value.toInt();
    lastHRTimestamp.value = data.timestamp;

    // Add to history
    heartRateHistory.add(data);

    // Keep last 60 minutes
    final cutoff = DateTime.now().subtract(const Duration(minutes: 60));
    heartRateHistory.removeWhere((p) => p.timestamp.isBefore(cutoff));

    // Decimate for chart
    _decimateHeartRateData();
  }

  void _decimateStepsData() {
    if (stepsHistory.length <= 100) {
      decimatedSteps.value = List.from(stepsHistory);
      return;
    }

    // Use LTTB algorithm
    decimatedSteps.value = Decimation.lttb(stepsHistory, 100);
  }

  void _decimateHeartRateData() {
    var data = List<HealthDataPoint>.from(heartRateHistory);

    // Apply smoothing if enabled
    if (hrSmoothingEnabled.value && data.length > 5) {
      data = _applyMovingAverage(data, 5);
    }

    if (data.length <= 100) {
      decimatedHeartRate.value = data;
      return;
    }

    // Use LTTB algorithm
    decimatedHeartRate.value = Decimation.lttb(data, 100);
  }

  List<HealthDataPoint> _applyMovingAverage(
    List<HealthDataPoint> data,
    int window,
  ) {
    final result = <HealthDataPoint>[];

    for (var i = 0; i < data.length; i++) {
      final start = (i - window ~/ 2).clamp(0, data.length);
      final end = (i + window ~/ 2 + 1).clamp(0, data.length);

      final subset = data.sublist(start, end);
      final avg =
          subset.map((p) => p.value).reduce((a, b) => a + b) / subset.length;

      result.add(
        HealthDataPoint(
          type: data[i].type,
          value: avg,
          timestamp: data[i].timestamp,
          recordId: data[i].recordId,
        ),
      );
    }

    return result;
  }

  void toggleHRSmoothing() {
    hrSmoothingEnabled.value = !hrSmoothingEnabled.value;
    _decimateHeartRateData();
  }

  void setStepsWindow(int minutes) {
    stepsWindowMinutes.value = minutes;
    _processStepsData(
      stepsHistory.isEmpty
          ? HealthDataPoint(type: 'STEPS', value: 0, timestamp: DateTime.now())
          : stepsHistory.last,
    );
  }

  void recordBuildTime(double milliseconds) {
    _buildTimes.add(milliseconds);
    if (_buildTimes.length > 100) {
      _buildTimes.removeAt(0);
    }

    if (_buildTimes.isNotEmpty) {
      avgBuildTime.value =
          _buildTimes.reduce((a, b) => a + b) / _buildTimes.length;
    }
  }

  void recordPaintTime(double milliseconds) {
    lastPaintTime.value = milliseconds;
  }

  void _startMetricsCollection() {
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Estimate FPS based on build times
      if (avgBuildTime.value > 0) {
        fps.value = (1000 / avgBuildTime.value).clamp(0, 60);
      }
    });
  }

  @override
  void onClose() {
    _dataSubscription?.cancel();
    _metricsTimer?.cancel();
    super.onClose();
  }
}
