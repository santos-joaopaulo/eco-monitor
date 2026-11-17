// Methods ----------------------------------------------------------------- //

/// Formats a distance in meters for the UI, using the pt-BR decimal comma.
///
/// Examples: `450` -> `"450 m"`; `1300` -> `"1,3 km"`.
String formatDistance(double meters) {
  final double safeMeters = meters.abs();

  if (safeMeters < 1000) {
    return "${safeMeters.round()} m";
  }

  final String kilometers = (safeMeters / 1000).toStringAsFixed(1);

  return "${kilometers.replaceAll(".", ",")} km";
}

/// Formats a duration in minutes for the UI.
///
/// Examples: `6` -> `"6 min"`; `65` -> `"1 h 5 min"`.
String formatDuration(double minutes) {
  final int totalMinutes = minutes.isFinite && minutes > 0
      ? minutes.round()
      : 0;

  if (totalMinutes < 60) {
    return "$totalMinutes min";
  }

  final int hours = totalMinutes ~/ 60;
  final int remainingMinutes = totalMinutes % 60;

  if (remainingMinutes == 0) {
    return "$hours h";
  }

  return "$hours h $remainingMinutes min";
}
