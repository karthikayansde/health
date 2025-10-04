import 'dart:async';
import 'dart:ffi';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:health/health.dart' as health_pkg;
import 'package:url_launcher/url_launcher.dart';
import '../models/health_data_point.dart';

class HealthConnectService extends GetxService {
  static const EventChannel _eventChannel = EventChannel(
    'com.healthconnect.dashboard/health_updates',
  );
  static const MethodChannel _methodChannel = MethodChannel(
    'com.healthconnect.dashboard/health_methods',
  );

  /// Check via native layer whether Health Connect app is installed/available.
  Future<bool> isHealthConnectAvailable() async {
    try {
      final available = await _methodChannel.invokeMethod<bool>(
        'isHealthConnectAvailable',
      );
      return available ?? false;
    } catch (e) {
      print('Error checking native Health Connect availability: $e');
      return false;
    }
  }

  /// Debug helper: list installed packages that contain 'health' in the package name.
  Future<List<String>> listHealthPackages() async {
    try {
      final packages = await _methodChannel.invokeMethod<List>(
        'listHealthPackages',
      );
      if (packages == null) return [];
      return packages.map((e) => e.toString()).toList();
    } catch (e) {
      print('Error listing health packages: $e');
      return [];
    }
  }
  // Uses the 'health_pkg' alias to access types from the health package
  final health = health_pkg.Health();
  final _seenRecords = <String>{};
  Timer? _changesPollingTimer;
  String? _changesToken;
  // Simulator state
  Timer? _simTimer;
  final math.Random _rand = math.Random();
  double _simHeartRate = 70.0;
  int _simStepsTotal = 0;

  final isSimMode = false.obs;
  // Single output stream that emits both real and simulated data. This avoids a
  // race where consumers subscribe to one stream before the simulator starts.
  final StreamController<HealthDataPoint> _outputController =
      StreamController<HealthDataPoint>.broadcast();

  @override
  void onInit() {
    super.onInit();
    _setupEventChannel();
    // If Health Connect isn't available, start simulator so the app behaves like production.
    isHealthConnectAvailable().then((available) {
      if (!available) {
        print('Starting simulator because Health Connect is not available');
        enableSimMode();
        // _startSimulator();
      }
    });
  }

  void _startSimulator() {
    _simTimer?.cancel();
    // Heart rate updates every second
    _simTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      // small random walk
      _simHeartRate += (_rand.nextDouble() - 0.5) * 2.0;
      _simHeartRate = _simHeartRate.clamp(50.0, 120.0);
      emitSimData('HEART_RATE', _simHeartRate);

      // Steps increment every 5 seconds
      if (t.tick % 5 == 0) {
        final stepIncrement = 10 + _rand.nextInt(30);
        _simStepsTotal += stepIncrement;
        emitSimData('STEPS', _simStepsTotal.toDouble());
      }
    });
  }

  void _stopSimulator() {
    _simTimer?.cancel();
    _simTimer = null;
  }

  void _setupEventChannel() {
    // Listen to native EventChannel and forward mapped HealthDataPoint into output stream
    _eventChannel.receiveBroadcastStream().listen(
      (data) {
        try {
          final map = Map<String, dynamic>.from(data);
          final dp = HealthDataPoint.fromMap(map);
          _outputController.add(dp);
        } catch (e) {
          print('Failed to map event channel data: $e');
        }
      },
      onError: (err) {
        print('EventChannel error: $err');
      },
    );
  }

  Stream<HealthDataPoint> get dataStream {
    return _outputController.stream;
  }

  Future<Map<String, bool>> checkPermissions() async {
    final available = await isHealthConnectAvailable();
    if (!available) {
      print('Health Connect not installed (native check).');
      return {'STEPS': false, 'HEART_RATE': false};
    }
    final types = [
      // Uses the aliased HealthDataType
      health_pkg.HealthDataType.STEPS,
      health_pkg.HealthDataType.HEART_RATE,
    ];

    try {
      final hasPermissions = await health.hasPermissions(types);
      return {
        'STEPS': hasPermissions ?? false,
        'HEART_RATE': hasPermissions ?? false,
      };
    } catch (e) {
      // If Health Connect isn't available, the health package throws an Unsupported operation
      print('Error checking permissions: $e');
      if (e.toString().contains('Health Connect is not available') ||
          e.toString().contains('Unsupported operation')) {
        // Optionally notify the UI to prompt user to install Health Connect
        print(
          'Health Connect not available on device. You can call installHealthConnect() to open the Play Store.',
        );
      }
      return {'STEPS': false, 'HEART_RATE': false};
    }
  }

  Future<bool> requestPermissions() async {
    final available = await isHealthConnectAvailable();
    if (!available) {
      print('Health Connect not installed (native check).');
      return false;
    }
    final types = [
      // Uses the aliased HealthDataType
      health_pkg.HealthDataType.STEPS,
      health_pkg.HealthDataType.HEART_RATE,
    ];

    try {
      final granted = await health.requestAuthorization(types);
      if (granted) {
        await _startPassiveListener();
      }
      return granted;
    } catch (e) {
      print('Error requesting permissions: $e');
      if (e.toString().contains('Health Connect is not available') ||
          e.toString().contains('Unsupported operation')) {
        print(
          'Health Connect not available on device. You can call installHealthConnect() to open the Play Store.',
        );
      }
      return false;
    }
  }

  /// Open Play Store to install Google Health Connect, with web fallback.
  Future<void> installHealthConnect() async {
    final playStoreUri = Uri.parse(
      'market://details?id=com.google.android.apps.healthdata',
    );
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
    );

    try {
      if (!await launchUrl(
        playStoreUri,
        mode: LaunchMode.externalApplication,
      )) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Failed to launch installer: $e');
    }
  }

  Future<void> _startPassiveListener() async {
    try {
      // Ensure the MethodChannel call is awaited
      await _methodChannel.invokeMethod('startPassiveListener');
    } catch (e) {
      print('Passive Listener setup failed, falling back to polling: $e');
      // Fallback to polling if passive listener fails
      _startChangesPolling();
    }
  }

  void _startChangesPolling() {
    _changesPollingTimer?.cancel();
    _changesPollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollChanges(),
    );
  }

  Future<void> _pollChanges() async {
    final now = DateTime.now();
    final types = [
      // Uses the aliased HealthDataType
      health_pkg.HealthDataType.STEPS,
      health_pkg.HealthDataType.HEART_RATE,
    ];

    try {
      final data = await health.getHealthDataFromTypes(
        startTime: now.subtract(const Duration(minutes: 1)),
        endTime: now,
        types: types,
      );
      // final data = await health.getHealthDataFromTypes(
      //   now.subtract(const Duration(minutes: 1)),
      //   now,
      //   types,
      // );

      for (var point in data) {
        final id = '${point.type}_${point.dateFrom.millisecondsSinceEpoch}';
        if (_seenRecords.contains(id)) continue;

        _seenRecords.add(id);
        // Clean up the set to prevent excessive memory usage
        if (_seenRecords.length > 1000) {
          // Remove the oldest element (approximation for a Set)
          _seenRecords.remove(_seenRecords.first);
        }

        // Use the point.type enum to determine the string type
        final String dataType;
        if (point.type == health_pkg.HealthDataType.STEPS) {
          dataType = 'STEPS';
        } else if (point.type == health_pkg.HealthDataType.HEART_RATE) {
          dataType = 'HEART_RATE';
        } else {
          continue; // Skip unknown types
        }

        final dataPoint = HealthDataPoint(
          type: dataType,
          value: double.parse(point.value.toString()),
          timestamp: point.dateFrom,
          recordId: id,
        );

        // Since this is a fallback, let's just log the data for now.
        print('Polling found new data: $dataType, Value: ${dataPoint.value}');
      }
    } catch (e) {
      // Handle error silently
      print('Error during polling: $e');
    }
  }

  void enableSimMode() {
    isSimMode.value = true;
  }

  void disableSimMode() {
    isSimMode.value = false;
  }

  void emitSimData(String type, double value) {
    if (!isSimMode.value) return;

    final dataPoint = HealthDataPoint(
      type: type,
      value: value,
      timestamp: DateTime.now(),
      recordId: 'sim_${DateTime.now().millisecondsSinceEpoch}',
    );

    // Log to help debug the simulator path
    print(
      'Simulator emitting: ${dataPoint.type} = ${dataPoint.value} at ${dataPoint.timestamp}',
    );
    _outputController.add(dataPoint);
  }

  @override
  void onClose() {
    _changesPollingTimer?.cancel();
    _stopSimulator();
    _outputController.close();
    super.onClose();
  }
}
