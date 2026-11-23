import "waste_type.dart";


// Enums ------------------------------------------------------------------- //


/// Indica se a campanha está ativa, prevista ou já encerrada.
enum CampaignStatus { active, upcoming, finished }


// Classes ----------------------------------------------------------------- //


/// Uma campanha de coleta exibida aos usuários (Entidade de Domínio).
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


  /// Constrói uma campanha a partir de JSON, tolerando campos ausentes e valores desconhecidos.
  factory Campaign.fromJson(Map<String, dynamic> json) {
    final Set<WasteType> wasteTypes = wasteTypesFromJson(json["wasteTypes"]);

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
