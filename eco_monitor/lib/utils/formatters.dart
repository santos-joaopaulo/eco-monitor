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

/// Formats a compact pt-BR date range for campaign cards.
///
/// Examples:
/// - Same day: `"05/12"`
/// - Same month: `"15–30/11"`
/// - Different months: `"28/11–05/12"`
String formatCampaignDateRange(DateTime startDate, DateTime endDate) {
  final DateTime start = startDate.toLocal();
  final DateTime end = endDate.toLocal();

  final String startDay = _twoDigits(start.day);
  final String startMonth = _twoDigits(start.month);
  final String endDay = _twoDigits(end.day);
  final String endMonth = _twoDigits(end.month);

  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return "$startDay/$startMonth";
  }

  if (start.year == end.year && start.month == end.month) {
    return "$startDay–$endDay/$startMonth";
  }

  return "$startDay/$startMonth–$endDay/$endMonth";
}

/// Formats a full pt-BR period (dates and optional hours) for campaign details.
///
/// Example: `"15/11/2026 a 30/11/2026 · 08h às 17h"`.
String formatCampaignPeriod(DateTime startDate, DateTime endDate) {
  final DateTime start = startDate.toLocal();
  final DateTime end = endDate.toLocal();

  final String startLabel =
      "${_twoDigits(start.day)}/${_twoDigits(start.month)}/${start.year}";
  final String endLabel =
      "${_twoDigits(end.day)}/${_twoDigits(end.month)}/${end.year}";

  final String datePart = startLabel == endLabel
      ? startLabel
      : "$startLabel a $endLabel";

  final bool hasHours =
      start.hour != 0 || start.minute != 0 || end.hour != 0 || end.minute != 0;

  if (!hasHours) {
    return datePart;
  }

  final String startTime = _formatTime(start);
  final String endTime = _formatTime(end);
  return "$datePart · $startTime às $endTime";
}

String _twoDigits(int value) => value.toString().padLeft(2, "0");

String _formatTime(DateTime dateTime) {
  final String hour = _twoDigits(dateTime.hour);
  if (dateTime.minute == 0) {
    return "${hour}h";
  }

  return "${hour}h${_twoDigits(dateTime.minute)}";
}
