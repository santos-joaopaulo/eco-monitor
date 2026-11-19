import "dart:async";

import "package:flutter/foundation.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";

import "../models/collection_point.dart";
import "point_pin.dart";


// Classes ----------------------------------------------------------------- //


/// Renderiza os pontos de coleta ativos como anotações de ponto do Mapbox.
///
/// Anotações nativas não são suportadas no Mapbox web, portanto [create] retorna
/// null nessa plataforma e a tela inicial continua funcionando sem os marcadores.
class CollectPointsLayer {
  CollectPointsLayer._(this._manager, this._images, this._onPointSelected);

  final PointAnnotationManager _manager;
  final Map<String, Uint8List> _images;
  final ValueChanged<CollectionPoint> _onPointSelected;

  Cancelable? _tapSubscription;
  Map<String, CollectionPoint> _pointsById = const <String, CollectionPoint>{};
  List<CollectionPoint> _latestPoints = const <CollectionPoint>[];
  String? _latestSelectedId;
  bool _hasPendingUpdate = false;
  bool _disposed = false;
  Future<void>? _updateQueue;


  // Methods --------------------------------------------------------------- //


  static Future<CollectPointsLayer?> create({
    required MapboxMap mapboxMap,
    required ValueChanged<CollectionPoint> onPointSelected,
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

      final CollectPointsLayer layer = CollectPointsLayer._(
        manager,
        images,
        onPointSelected,
      );
      layer._listenToTaps();
      await hideDefaultPois(mapboxMap);

      return layer;
    } catch (_) {
      return null;
    }
  }

  /// Oculta as camadas de símbolos de POI fornecidas pelo estilo atual quando possível.
  ///
  /// O estilo Mapbox Standard mantém parte de seus POIs dentro de importações de estilo,
  /// que esta API não expõe como camadas individuais.
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
          // Algumas camadas importadas são somente leitura; mantém o mapa utilizável.
        }
      }
    } catch (_) {
      // Ignora estilos sem camadas inspecionáveis.
    }
  }

  void update(List<CollectionPoint> points, {String? selectedId}) {
    if (_disposed) {
      return;
    }

    _latestPoints = points;
    _latestSelectedId = selectedId;
    _hasPendingUpdate = true;
    _updateQueue ??= _runUpdates();
  }

  Future<void> _runUpdates() async {
    while (_hasPendingUpdate && !_disposed) {
      _hasPendingUpdate = false;

      final List<CollectionPoint> points = _latestPoints;
      final String? selectedId = _latestSelectedId;

      _pointsById = <String, CollectionPoint>{
        for (final CollectionPoint point in points) point.id: point,
      };

      final List<PointAnnotationOptions> options = <PointAnnotationOptions>[
        for (final CollectionPoint point in points)
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(point.longitude, point.latitude),
            ),
            image:
                _images[_imageKey(
                  point.type,
                  selected: point.id == selectedId,
                )],
            iconAnchor: IconAnchor.BOTTOM,
            iconSize: point.id == selectedId ? 0.58 : 0.48,
            symbolSortKey: point.id == selectedId ? 10 : 0,
            customData: <String, Object>{"id": point.id},
          ),
      ];

      try {
        await _manager.deleteAll();
        if (_disposed) {
          return;
        }
        if (options.isNotEmpty) {
          await _manager.createMulti(options);
        }
      } catch (_) {
        // Uma falha de redesenho não deve quebrar o mapa nem os filtros.
      }
    }

    _updateQueue = null;
  }

  void _listenToTaps() {
    _tapSubscription = _manager.tapEvents(
      onTap: (PointAnnotation annotation) {
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


// Methods ----------------------------------------------------------------- //


String _imageKey(PointType type, {required bool selected}) {
  return "${type.name}-${selected ? "selected" : "default"}";
}

bool _isPoiLayer(String id) {
  final String lower = id.toLowerCase();
  return lower.contains("poi") || lower.contains("transit");
}
