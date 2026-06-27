class FoodPrediction {
  final String name;
  final double confidence; // 0.0 – 1.0

  const FoodPrediction({
    required this.name,
    required this.confidence,
  });

  factory FoodPrediction.fromJson(Map<String, dynamic> json) {
    return FoodPrediction(
      name: json['name'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}