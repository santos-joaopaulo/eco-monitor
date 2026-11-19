import "collection_point.dart";

// Enums ------------------------------------------------------------------- //

/// Whether the campaign is running, upcoming, or already finished.
enum CampaignStatus { active, upcoming, finished }

// Classes ----------------------------------------------------------------- //

/// A collection campaign shown to users (RF08, RF09, RNF11).
class Campaign {
  Campaign({
    required this.id,
    required this.title,
    required this.description,
    required Set<WasteType> wasteTypes,
    required this.locationName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.startDate,
    required this.endDate,
    required this.status,
  }) : wasteTypes = Set<WasteType>.unmodifiable(wasteTypes);

  final String id;
  final String title;
  final String description;
  final Set<WasteType> wasteTypes;
  final String locationName;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime startDate;
  final DateTime endDate;
  final CampaignStatus status;

  bool get isActive => status == CampaignStatus.active;

  bool get isUpcoming => status == CampaignStatus.upcoming;

  bool accepts(WasteType wasteType) => wasteTypes.contains(wasteType);

  // Methods --------------------------------------------------------------- //

  /// Builds a campaign from JSON, tolerating missing fields and unknown values.
  ///
  /// Unknown waste types are ignored, unknown statuses fall back to finished
  /// (never shown as active by accident).
  factory Campaign.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawWasteTypes = switch (json["wasteTypes"]) {
      final List<dynamic> values => values,
      _ => const <dynamic>[],
    };

    final Set<WasteType> wasteTypes = rawWasteTypes
        .whereType<String>()
        .map(_wasteTypeByName)
        .whereType<WasteType>()
        .toSet();

    return Campaign(
      id: _asString(json["id"]),
      title: _asString(json["title"]),
      description: _asString(json["description"]),
      wasteTypes: wasteTypes,
      locationName: _asString(json["locationName"]),
      address: _asString(json["address"]),
      latitude: _asDouble(json["latitude"]),
      longitude: _asDouble(json["longitude"]),
      startDate: _asDateTime(json["startDate"]),
      endDate: _asDateTime(json["endDate"]),
      status: _campaignStatusByName(_asString(json["status"])),
    );
  }

  Map<String, dynamic> toJson() {
    final List<String> waste =
        wasteTypes.map((WasteType type) => type.name).toList()..sort();

    return {
      "id": id,
      "title": title,
      "description": description,
      "wasteTypes": waste,
      "locationName": locationName,
      "address": address,
      "latitude": latitude,
      "longitude": longitude,
      "startDate": startDate.toIso8601String(),
      "endDate": endDate.toIso8601String(),
      "status": status.name,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is Campaign && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => "Campaign($id, $title)";
}

// Methods ----------------------------------------------------------------- //

WasteType? _wasteTypeByName(String name) {
  for (final WasteType type in WasteType.values) {
    if (type.name == name) {
      return type;
    }
  }

  return null;
}

CampaignStatus _campaignStatusByName(String name) {
  for (final CampaignStatus status in CampaignStatus.values) {
    if (status.name == name) {
      return status;
    }
  }

  return CampaignStatus.finished;
}

String _asString(Object? value) => value is String ? value : "";

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? "") ?? 0;
}

DateTime _asDateTime(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
