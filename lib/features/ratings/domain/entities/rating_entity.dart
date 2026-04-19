import 'package:equatable/equatable.dart';

class Rating extends Equatable {
  final String id;
  final String emergencyId;
  final String raterId;
  final String ratedId;
  final int stars;
  final String? review;
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.emergencyId,
    required this.raterId,
    required this.ratedId,
    required this.stars,
    this.review,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, emergencyId, raterId, ratedId, stars, review, createdAt];
}
