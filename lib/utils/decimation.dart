import 'dart:math';
import '../models/health_data_point.dart';

class Decimation {
  /// Largest Triangle Three Buckets algorithm for downsampling
  static List<HealthDataPoint> lttb(List<HealthDataPoint> data, int threshold) {
    if (data.length <= threshold) {
      return data;
    }

    final result = <HealthDataPoint>[];

    // Always include first point
    result.add(data.first);

    // Bucket size
    final bucketSize = (data.length - 2) / (threshold - 2);

    // Index of point in the current bucket
    var a = 0;

    for (var i = 0; i < threshold - 2; i++) {
      // Calculate point average for next bucket
      final avgRangeStart = ((i + 1) * bucketSize + 1).floor();
      final avgRangeEnd = ((i + 2) * bucketSize + 1).floor().clamp(0, data.length);

      final avgRangeLength = avgRangeEnd - avgRangeStart;

      var avgX = 0.0;
      var avgY = 0.0;

      for (var j = avgRangeStart; j < avgRangeEnd; j++) {
        avgX += data[j].timestamp.millisecondsSinceEpoch.toDouble();
        avgY += data[j].value;
      }
      avgX /= avgRangeLength;
      avgY /= avgRangeLength;

      // Get the range for this bucket
      final rangeOffs = (i * bucketSize + 1).floor();
      final rangeTo = ((i + 1) * bucketSize + 1).floor();

      // Point a
      final pointAX = data[a].timestamp.millisecondsSinceEpoch.toDouble();
      final pointAY = data[a].value;

      var maxArea = -1.0;
      var maxAreaPoint = 0;

      for (var j = rangeOffs; j < rangeTo; j++) {
        if (j >= data.length) break;

        final area = ((pointAX - avgX) * (data[j].value - pointAY) -
            (pointAX - data[j].timestamp.millisecondsSinceEpoch) *
                (avgY - pointAY))
            .abs();

        if (area > maxArea) {
          maxArea = area;
          maxAreaPoint = j;
        }
      }

      result.add(data[maxAreaPoint]);
      a = maxAreaPoint;
    }

    // Always include last point
    result.add(data.last);

    return result;
  }

  /// Simple decimation by taking every nth point
  static List<HealthDataPoint> everyNth(List<HealthDataPoint> data, int n) {
    if (n <= 1) return data;

    final result = <HealthDataPoint>[];
    for (var i = 0; i < data.length; i += n) {
      result.add(data[i]);
    }

    if (result.isEmpty || result.last != data.last) {
      result.add(data.last);
    }

    return result;
  }

  /// Min-max decimation: keep min and max in each bucket
  static List<HealthDataPoint> minMax(List<HealthDataPoint> data, int buckets) {
    if (data.length <= buckets * 2) {
      return data;
    }

    final result = <HealthDataPoint>[];
    final bucketSize = data.length / buckets;

    for (var i = 0; i < buckets; i++) {
      final start = (i * bucketSize).floor();
      final end = ((i + 1) * bucketSize).ceil().clamp(0, data.length);

      final bucket = data.sublist(start, end);
      if (bucket.isEmpty) continue;

      // Find min and max
      var minPoint = bucket.first;
      var maxPoint = bucket.first;

      for (var point in bucket) {
        if (point.value < minPoint.value) minPoint = point;
        if (point.value > maxPoint.value) maxPoint = point;
      }

      // Add in chronological order
      if (minPoint.timestamp.isBefore(maxPoint.timestamp)) {
        result.add(minPoint);
        if (minPoint != maxPoint) result.add(maxPoint);
      } else {
        result.add(maxPoint);
        if (minPoint != maxPoint) result.add(minPoint);
      }
    }

    return result;
  }
}