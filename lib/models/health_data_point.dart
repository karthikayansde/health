class HealthDataPoint {
  final String type;
  final double value;
  final DateTime timestamp;
  final String? recordId;

  HealthDataPoint({
    required this.type,
    required this.value,
    required this.timestamp,
    this.recordId,
  });

  factory HealthDataPoint.fromMap(Map<String, dynamic> map) {
    return HealthDataPoint(
      type: map['type'] as String,
      value: (map['value'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
      ),
      recordId: map['recordId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'recordId': recordId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HealthDataPoint &&
        other.recordId == recordId &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => recordId.hashCode ^ timestamp.hashCode;
}