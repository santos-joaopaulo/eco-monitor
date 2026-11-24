import "package:flutter/foundation.dart";


// Enums ------------------------------------------------------------------- //


/// Estado do ciclo de vida de um pacote estadual de navegação offline.
enum OfflinePackageStatus {
  notDownloaded,
  downloading,
  downloaded,
}


// Classes ----------------------------------------------------------------- //


/// Representa um pacote regional/estadual de navegação vetorial offline.
@immutable
class OfflinePackage {
  const OfflinePackage({
    required this.id,
    required this.stateCode,
    required this.name,
    required this.region,
    required this.sizeBytes,
    required this.bbox,
    this.status = OfflinePackageStatus.notDownloaded,
    this.downloadProgress = 0.0,
    this.isBuiltIn = false,
    this.localFilePath,
  });

  /// Identificador único (ex.: "br-se", "br-ba", "br-sp").
  final String id;

  /// Sigla da Unidade Federativa (ex.: "SE", "BA", "SP").
  final String stateCode;

  /// Nome por extenso do estado (ex.: "Sergipe", "Bahia", "São Paulo").
  final String name;

  /// Região geográfica do Brasil (ex.: "Nordeste", "Sudeste", "Sul", "Norte", "Centro-Oeste").
  final String region;

  /// Tamanho estimado ou real do pacote em bytes.
  final int sizeBytes;

  /// Caixa delimitadora geográfica [minLat, minLon, maxLat, maxLon].
  final List<double> bbox;

  /// Status atual do download e armazenamento do pacote.
  final OfflinePackageStatus status;

  /// Progresso atual de download (0.0 a 1.0).
  final double downloadProgress;

  /// Indica se o pacote já vem pré-instalado com o aplicativo (ex.: Sergipe/Aracaju).
  final bool isBuiltIn;

  /// Caminho no armazenamento local do dispositivo onde o arquivo do pacote reside.
  final String? localFilePath;

  bool get isDownloaded => status == OfflinePackageStatus.downloaded;
  bool get isDownloading => status == OfflinePackageStatus.downloading;

  /// Formatação amigável do tamanho em Megabytes (MB).
  String get formattedSize {
    final double mb = sizeBytes / (1024 * 1024);
    if (mb < 0.1) {
      return "${(sizeBytes / 1024).toStringAsFixed(0)} KB";
    }
    return "${mb.toStringAsFixed(1).replaceAll('.', ',')} MB";
  }

  /// Verifica se uma coordenada geográfica está contida nos limites da bounding box.
  bool containsCoordinate(double latitude, double longitude) {
    if (bbox.length < 4) {
      return false;
    }
    final double minLat = bbox[0];
    final double minLon = bbox[1];
    final double maxLat = bbox[2];
    final double maxLon = bbox[3];

    return latitude >= minLat &&
        latitude <= maxLat &&
        longitude >= minLon &&
        longitude <= maxLon;
  }

  OfflinePackage copyWith({
    String? id,
    String? stateCode,
    String? name,
    String? region,
    int? sizeBytes,
    List<double>? bbox,
    OfflinePackageStatus? status,
    double? downloadProgress,
    bool? isBuiltIn,
    String? localFilePath,
  }) {
    return OfflinePackage(
      id: id ?? this.id,
      stateCode: stateCode ?? this.stateCode,
      name: name ?? this.name,
      region: region ?? this.region,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      bbox: bbox ?? this.bbox,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "stateCode": stateCode,
      "name": name,
      "region": region,
      "sizeBytes": sizeBytes,
      "bbox": bbox,
      "status": status.name,
      "downloadProgress": downloadProgress,
      "isBuiltIn": isBuiltIn,
      if (localFilePath != null) "localFilePath": localFilePath,
    };
  }

  factory OfflinePackage.fromJson(Map<String, dynamic> json) {
    final String rawStatus = json["status"] as String? ?? "notDownloaded";
    final OfflinePackageStatus parsedStatus = OfflinePackageStatus.values
        .firstWhere(
          (OfflinePackageStatus s) => s.name == rawStatus,
          orElse: () => OfflinePackageStatus.notDownloaded,
        );

    final List<dynamic>? rawBbox = json["bbox"] as List<dynamic>?;
    final List<double> parsedBbox = rawBbox != null
        ? rawBbox.map((dynamic item) => (item as num).toDouble()).toList()
        : const <double>[];

    return OfflinePackage(
      id: json["id"] as String,
      stateCode: json["stateCode"] as String,
      name: json["name"] as String,
      region: json["region"] as String,
      sizeBytes: (json["sizeBytes"] as num?)?.toInt() ?? 0,
      bbox: parsedBbox,
      status: parsedStatus,
      downloadProgress:
          (json["downloadProgress"] as num?)?.toDouble() ?? 0.0,
      isBuiltIn: json["isBuiltIn"] as bool? ?? false,
      localFilePath: json["localFilePath"] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is OfflinePackage &&
        other.id == id &&
        other.stateCode == stateCode &&
        other.name == name &&
        other.region == region &&
        other.sizeBytes == sizeBytes &&
        other.status == status &&
        other.downloadProgress == downloadProgress &&
        other.isBuiltIn == isBuiltIn &&
        other.localFilePath == localFilePath;
  }

  @override
  int get hashCode => Object.hash(
        id,
        stateCode,
        name,
        region,
        sizeBytes,
        status,
        downloadProgress,
        isBuiltIn,
        localFilePath,
      );
}

/// Emite o progresso contínuo de download de um pacote de navegação offline.
@immutable
class OfflinePackageProgress {
  const OfflinePackageProgress({
    required this.packageId,
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
    required this.status,
  });

  /// Identificador do pacote sendo transferido.
  final String packageId;

  /// Progresso percentual normalizado de 0.0 a 1.0.
  final double progress;

  /// Quantidade de bytes recebidos até o momento.
  final int receivedBytes;

  /// Quantidade total esperada de bytes.
  final int totalBytes;

  /// Status atual do download.
  final OfflinePackageStatus status;

  OfflinePackageProgress copyWith({
    String? packageId,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    OfflinePackageStatus? status,
  }) {
    return OfflinePackageProgress(
      packageId: packageId ?? this.packageId,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is OfflinePackageProgress &&
        other.packageId == packageId &&
        other.progress == progress &&
        other.receivedBytes == receivedBytes &&
        other.totalBytes == totalBytes &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(
        packageId,
        progress,
        receivedBytes,
        totalBytes,
        status,
      );
}
