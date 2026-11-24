import "dart:async";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";

import "../domain/entities/collection_point.dart";
import "../utils/geo.dart";
import "point_pin.dart";


// Classes ------------------------------------------------------------------ //


/// Agrupador de pontos para exibição desclusterizada ou agrupada em cluster no Mapbox.
class _ClusterGroup {
  _ClusterGroup._({
    required this.centerLat,
    required this.centerLon,
    required this.sumLat,
    required this.sumLon,
    required this.points,
  });

  factory _ClusterGroup.single(CollectionPoint point) {
    return _ClusterGroup._(
      centerLat: point.latitude,
      centerLon: point.longitude,
      sumLat: point.latitude,
      sumLon: point.longitude,
      points: <CollectionPoint>[point],
    );
  }

  double centerLat;
  double centerLon;
  double sumLat;
  double sumLon;
  final List<CollectionPoint> points;

  void add(CollectionPoint point) {
    points.add(point);
    // Atualiza a coordenada média do centro do cluster em O(1) usando acumuladores
    sumLat += point.latitude;
    sumLon += point.longitude;
    centerLat = sumLat / points.length;
    centerLon = sumLon / points.length;
  }
}


/// Renderiza os pontos de coleta ativos e clusters dinâmicos como anotações do Mapbox (T11.2).
///
/// Em níveis moderados ou baixos de zoom (< 14.0), agrupa ecopontos próximos em bolhas
/// circulares estilizadas exibindo a contagem acumulada. Ao tocar no cluster, a câmera
/// anima aumentando o zoom para expandir os pontos individuais.
class CollectPointsLayer {
  CollectPointsLayer._(
    this._mapboxMap,
    this._manager,
    this._images,
    this._onPointSelected, {
    this.onClusterSelected,
  });

  final MapboxMap _mapboxMap;
  final PointAnnotationManager _manager;
  final Map<String, Uint8List> _images;
  final ValueChanged<CollectionPoint> _onPointSelected;
  final void Function(double lat, double lon, double nextZoom)? onClusterSelected;

  Cancelable? _tapSubscription;
  Map<String, CollectionPoint> _pointsById = const <String, CollectionPoint>{};
  List<CollectionPoint> _latestPoints = const <CollectionPoint>[];
  String? _latestSelectedId;
  double _currentZoom = 13.0;
  bool _hasPendingUpdate = false;
  bool _disposed = false;
  Future<void>? _updateQueue;


// Methods ------------------------------------------------------------------ //


  static Future<CollectPointsLayer?> create({
    required MapboxMap mapboxMap,
    required ValueChanged<CollectionPoint> onPointSelected,
    void Function(double lat, double lon, double nextZoom)? onClusterSelected,
  }) async {
    if (kIsWeb) {
      return null;
    }

    try {
      final Map<String, Uint8List> images = <String, Uint8List>{
        for (final PointType type in PointType.values) ...{
          _imageKey(type, selected: false): await PointPin.render(type: type),
          _imageKey(type, selected: true): await PointPin.render(
            type: type,
            selected: true,
          ),
        },
      };

      final PointAnnotationManager manager = await mapboxMap.annotations
          .createPointAnnotationManager();
      await manager.setIconAllowOverlap(true);
      await manager.setIconIgnorePlacement(true);

      final CollectPointsLayer layer = CollectPointsLayer._(
        mapboxMap,
        manager,
        images,
        onPointSelected,
        onClusterSelected: onClusterSelected,
      );
      layer._listenToTaps();
      await hideDefaultPois(mapboxMap);

      return layer;
    } catch (_) {
      return null;
    }
  }

  /// Oculta as camadas de símbolos de POI fornecidas pelo estilo atual quando possível.
  static Future<void> hideDefaultPois(MapboxMap mapboxMap) async {
    if (kIsWeb) {
      return;
    }

    try {
      final List<StyleObjectInfo?> layers = await mapboxMap.getStyleLayers();
      for (final StyleObjectInfo layer in layers.whereType<StyleObjectInfo>()) {
        if (layer.type != "symbol" || !_isPoiLayer(layer.id)) {
          continue;
        }

        try {
          await mapboxMap.setStyleLayerProperty(layer.id, "visibility", "none");
        } catch (_) {
          // Mantém o mapa utilizável caso a camada seja somente leitura.
        }
      }
    } catch (_) {
      // Ignora estilos sem camadas inspecionáveis.
    }
  }

  /// Notifica mudança no nível de zoom da câmera para recomputar clusters quando necessário.
  void updateCameraZoom(double zoom) {
    if (_disposed) {
      return;
    }

    // Recomputa marcadores apenas se houver variação perceptível no nível de zoom
    if ((zoom - _currentZoom).abs() >= 0.5) {
      _currentZoom = zoom;
      _hasPendingUpdate = true;
      _updateQueue ??= _runUpdates();
    }
  }

  /// Atualiza o conjunto de pontos e o identificador do ponto atualmente selecionado.
  void update(
    List<CollectionPoint> points, {
    String? selectedId,
    double? currentZoom,
  }) {
    if (_disposed) {
      return;
    }

    _latestPoints = points;
    _latestSelectedId = selectedId;
    if (currentZoom != null) {
      _currentZoom = currentZoom;
    }
    _hasPendingUpdate = true;
    _updateQueue ??= _runUpdates();
  }

  Future<void> _runUpdates() async {
    while (_hasPendingUpdate && !_disposed) {
      _hasPendingUpdate = false;

      final List<CollectionPoint> points = _latestPoints;
      final String? selectedId = _latestSelectedId;
      final double zoom = _currentZoom;

      _pointsById = <String, CollectionPoint>{
        for (final CollectionPoint point in points) point.id: point,
      };

      final List<_ClusterGroup> groups = _clusterPoints(points, zoom);
      final List<PointAnnotationOptions> options = <PointAnnotationOptions>[];

      for (final _ClusterGroup group in groups) {
        if (group.points.length == 1) {
          final CollectionPoint point = group.points.first;
          final bool isSelected = point.id == selectedId;

          options.add(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(point.longitude, point.latitude),
              ),
              image: _images[_imageKey(point.type, selected: isSelected)],
              iconAnchor: IconAnchor.BOTTOM,
              iconSize: isSelected ? 0.95 : 0.82,
              symbolSortKey: isSelected ? 200 : 100,
              customData: <String, Object>{
                "id": point.id,
                "isCluster": false,
              },
            ),
          );
        } else {
          // Renderiza cluster com bolha circular estilizada e contagem acumulada (T11.2)
          final Uint8List clusterImage = await PointPin.renderCluster(
            count: group.points.length,
          );

          options.add(
            PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(group.centerLon, group.centerLat),
              ),
              image: clusterImage,
              iconAnchor: IconAnchor.CENTER,
              iconSize: 0.9,
              symbolSortKey: 150,
              customData: <String, Object>{
                "isCluster": true,
                "lat": group.centerLat,
                "lon": group.centerLon,
                "count": group.points.length,
              },
            ),
          );
        }
      }

      try {
        await _manager.deleteAll();
        if (_disposed) {
          return;
        }
        if (options.isNotEmpty) {
          await _manager.createMulti(options);
        }
      } catch (_) {
        // Redesenho resiliente sem quebrar o mapa.
      }
    }

    _updateQueue = null;
  }

  /// Agrupa pontos com base no nível de zoom e na distância geográfica proporcional.
  List<_ClusterGroup> _clusterPoints(List<CollectionPoint> points, double zoom) {
    if (zoom >= 14.0 || points.isEmpty) {
      return points.map((p) => _ClusterGroup.single(p)).toList();
    }

    // Limiar de proximidade em metros reduz conforme o zoom aproxima
    final double clusterDistance =
        35000.0 / math.pow(2.0, (zoom - 8.0).clamp(0.0, 10.0));
    final List<_ClusterGroup> groups = <_ClusterGroup>[];

    for (final CollectionPoint point in points) {
      _ClusterGroup? closestGroup;
      double closestDist = double.infinity;

      for (final _ClusterGroup group in groups) {
        final double dist = distanceInMeters(
          point.latitude,
          point.longitude,
          group.centerLat,
          group.centerLon,
        );

        if (dist <= clusterDistance && dist < closestDist) {
          closestDist = dist;
          closestGroup = group;
        }
      }

      if (closestGroup != null) {
        closestGroup.add(point);
      } else {
        groups.add(_ClusterGroup.single(point));
      }
    }

    return groups;
  }

  void _listenToTaps() {
    _tapSubscription = _manager.tapEvents(
      onTap: (PointAnnotation annotation) {
        final Object? isCluster = annotation.customData?["isCluster"];

        if (isCluster == true) {
          // Ao tocar em um cluster, anima a câmera aproximando e centralizando para expandir (T11.2)
          final double? lat = (annotation.customData?["lat"] as num?)?.toDouble();
          final double? lon = (annotation.customData?["lon"] as num?)?.toDouble();

          if (lat != null && lon != null) {
            final double nextZoom = (_currentZoom + 2.5).clamp(1.0, 16.0);
            unawaited(
              _mapboxMap.easeTo(
                CameraOptions(
                  center: Point(coordinates: Position(lon, lat)),
                  zoom: nextZoom,
                ),
                MapAnimationOptions(duration: 600),
              ),
            );
            onClusterSelected?.call(lat, lon, nextZoom);
          }
          return;
        }

        final Object? id = annotation.customData?["id"];
        if (id == null) {
          return;
        }

        final CollectionPoint? point = _pointsById[id.toString()];
        if (point != null) {
          _onPointSelected(point);
        }
      },
    );
  }

  void dispose() {
    _disposed = true;
    _tapSubscription?.cancel();
    _tapSubscription = null;
    unawaited(_manager.deleteAll().catchError((Object _) {}));
  }
}


// Methods ------------------------------------------------------------------ //


String _imageKey(PointType type, {required bool selected}) {
  return "${type.name}-${selected ? "selected" : "default"}";
}

bool _isPoiLayer(String id) {
  final String lower = id.toLowerCase();
  return lower.contains("poi") || lower.contains("transit");
}
