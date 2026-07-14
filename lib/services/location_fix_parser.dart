import '../models/lokalog_models.dart';

class ParsedLocationFix {
  ParsedLocationFix({required this.fix, this.errorMessage});

  final LocationFix? fix;
  final String? errorMessage;

  bool get isValid => fix != null;
}

class LocationFixParser {
  static ParsedLocationFix parse(Map<Object?, Object?>? payload) {
    final double? lat = (payload?['latitude'] as num?)?.toDouble();
    final double? lng = (payload?['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      return ParsedLocationFix(
        fix: null,
        errorMessage: 'GPS payload missing latitude or longitude.',
      );
    }

    if (!lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return ParsedLocationFix(
        fix: null,
        errorMessage: 'GPS payload returned invalid coordinates.',
      );
    }

    final double accuracy =
        ((payload?['accuracy'] as num?)?.toDouble() ?? 999).abs();
    final double speed = ((payload?['speed'] as num?)?.toDouble() ?? 0);

    return ParsedLocationFix(
      fix: LocationFix(
        lat: lat,
        lng: lng,
        accuracyMeters: accuracy.isFinite ? accuracy : 999,
        speedMetersPerSecond: speed.isFinite && speed >= 0 ? speed : 0,
      ),
    );
  }
}
