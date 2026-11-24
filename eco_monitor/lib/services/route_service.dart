import "dart:async";
import "dart:convert";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:url_launcher/url_launcher.dart";

import "../data/route_cache_store.dart";
import "../models/collection_point.dart";
import "../services/location_service.dart";
import "../utils/geo.dart";


// Constants ---------------------------------------------------------------- //


/// Raio em metros para considerar que o usuário chegou ao destino.
const double kArrivalThresholdMeters = 25;

/// Timeout máximo para chamadas à API de direções antes do fallback offline.
const Duration kRouteApiTimeout = Duration(seconds: 4);


// Types ------------------------------------------------------------------- //


/// Informações detalhadas da rota ativa exibidas ao usuário no app (RF04).
class RouteSummary {
  const RouteSummary({
    required this.distanceMeters,
    required this.estimatedMinutes,
    this.travelMode = TravelMode.walking,
    this.bearingDegrees = 0,
    this.cardinalDirection = "Norte",
    this.isArrived = false,
    this.isOfflineFallback = true,
    this.isFromCache = false,
    this.routeCoordinates = const <List<double>>[],
  });

  /// Distância total prevista em metros.
  final double distanceMeters;

  /// Tempo estimado em minutos.
  final int estimatedMinutes;

  /// Modal de deslocamento ativo.
  final TravelMode travelMode;

  /// Azimute do usuário em relação ao ponto (0° a 360°).
  final double bearingDegrees;

  /// Direção cardeal aproximada ("Norte", "Nordeste", etc.).
  final String cardinalDirection;

  /// Indica se o usuário está dentro do raio de chegada ao ponto.
  final bool isArrived;

  /// Indica se a rota está operando em modo offline/vetor direto.
  final bool isOfflineFallback;

  /// Indica se a rota foi recuperada do cache LRU local (T11.3).
  final bool isFromCache;

  /// Coordenadas [longitude, latitude] que compõem a polilinha no mapa.
  final List<List<double>> routeCoordinates;
}

typedef UriLauncher = Future<bool> Function(Uri uri);


// Classes ----------------------------------------------------------------- //


/// Constrói estimativas de rota (online via Mapbox Directions e fallback offline)
/// e provê navegação no próprio aplicativo ou atalho externo (RF04, RF05).
class RouteService {
  const RouteService({
    this.launcher,
    this.httpClient,
    this.cacheStore,
  });

  final UriLauncher? launcher;
  final http.Client? httpClient;
  final RouteCacheStore? cacheStore;

  static RouteCacheStore? _defaultStore;

  /// Retorna o [RouteCacheStore] efetivo associado a este serviço.
  RouteCacheStore get effectiveCacheStore =>
      cacheStore ?? (_defaultStore ??= RouteCacheStore());

  @visibleForTesting
  static set defaultStore(RouteCacheStore? store) {
    _defaultStore = store;
  }


  // Methods --------------------------------------------------------------- //


  /// Constrói a estimativa da rota offline baseada em vetor direto e fator viário urbano.
  RouteSummary buildRouteSummary(
    UserLocation userPosition,
    CollectionPoint point, {
    TravelMode travelMode = TravelMode.walking,
  }) {
    final double rawDistance = distanceInMeters(
      userPosition.latitude,
      userPosition.longitude,
      point.latitude,
      point.longitude,
    );

    final double distance = rawDistance * kUrbanDetourFactor;
    final double minutes = distance / travelMode.speedMetersPerSecond / 60;
    final int estimatedMinutes = rawDistance > 0
        ? minutes.round().clamp(1, 1 << 30)
        : 0;

    final double bearing = bearingInDegrees(
      userPosition.latitude,
      userPosition.longitude,
      point.latitude,
      point.longitude,
    );

    final bool arrived = rawDistance <= kArrivalThresholdMeters;

    return RouteSummary(
      distanceMeters: rawDistance <= kArrivalThresholdMeters ? 0 : distance,
      estimatedMinutes: arrived ? 0 : estimatedMinutes,
      travelMode: travelMode,
      bearingDegrees: bearing,
      cardinalDirection: cardinalDirectionFromDegrees(bearing),
      isArrived: arrived,
      isOfflineFallback: true,
      routeCoordinates: <List<double>>[
        <double>[userPosition.longitude, userPosition.latitude],
        <double>[point.longitude, point.latitude],
      ],
    );
  }

  /// Atualiza o resumo da rota a partir de uma nova coordenada de GPS em tempo real.
  RouteSummary buildUpdatedSummary(
    UserLocation userPosition,
    CollectionPoint point,
    TravelMode travelMode, {
    RouteSummary? previousSummary,
  }) {
    final double rawDistance = distanceInMeters(
      userPosition.latitude,
      userPosition.longitude,
      point.latitude,
      point.longitude,
    );

    final double bearing = bearingInDegrees(
      userPosition.latitude,
      userPosition.longitude,
      point.latitude,
      point.longitude,
    );

    final bool arrived = rawDistance <= kArrivalThresholdMeters;
    final bool isOffline = previousSummary?.isOfflineFallback ?? true;

    final double distance = isOffline
        ? rawDistance * kUrbanDetourFactor
        : (rawDistance <= kArrivalThresholdMeters ? 0 : rawDistance * kUrbanDetourFactor);

    final double minutes = distance / travelMode.speedMetersPerSecond / 60;
    final int estimatedMinutes = rawDistance > 0
        ? minutes.round().clamp(1, 1 << 30)
        : 0;

    final List<List<double>> coords = isOffline
        ? <List<double>>[
            <double>[userPosition.longitude, userPosition.latitude],
            <double>[point.longitude, point.latitude],
          ]
        : (previousSummary?.routeCoordinates ?? const <List<double>>[]);

    return RouteSummary(
      distanceMeters: arrived ? 0 : distance,
      estimatedMinutes: arrived ? 0 : estimatedMinutes,
      travelMode: travelMode,
      bearingDegrees: bearing,
      cardinalDirection: cardinalDirectionFromDegrees(bearing),
      isArrived: arrived,
      isOfflineFallback: isOffline,
      isFromCache: previousSummary?.isFromCache ?? false,
      routeCoordinates: coords,
    );
  }

  /// Busca a rota viária real na Mapbox Directions API, recorrendo a fallback offline em caso de erro ou sem rede.
  Future<RouteSummary> fetchRoute({
    required UserLocation origin,
    required CollectionPoint destination,
    TravelMode travelMode = TravelMode.walking,
    bool isOnline = true,
    String? accessToken,
    http.Client? client,
  }) async {
    // 1. Consulta prévia ao cache inteligente LRU (T11.3)
    final RouteCacheStore cache = effectiveCacheStore;
    final CachedRoute? cached = await cache.getRoute(
      originLat: origin.latitude,
      originLon: origin.longitude,
      destLat: destination.latitude,
      destLon: destination.longitude,
      travelMode: travelMode,
    );

    if (cached != null) {
      final double rawDirectDistance = distanceInMeters(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );
      final double bearing = bearingInDegrees(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );
      final bool arrived = rawDirectDistance <= kArrivalThresholdMeters;

      List<List<double>> effectiveCoords = cached.routeCoordinates;
      if (effectiveCoords.isNotEmpty) {
        final double distToFirst = distanceInMeters(
          origin.latitude,
          origin.longitude,
          effectiveCoords.first[1],
          effectiveCoords.first[0],
        );
        // Conecta a posição atual do usuário ao traçado viário se houver leve oscilação de GPS
        if (distToFirst > 5 && distToFirst <= 120) {
          effectiveCoords = <List<double>>[
            <double>[origin.longitude, origin.latitude],
            ...effectiveCoords,
          ];
        }
      }

      return RouteSummary(
        distanceMeters: arrived ? 0 : cached.distanceMeters,
        estimatedMinutes: arrived ? 0 : cached.estimatedMinutes,
        travelMode: cached.travelMode,
        bearingDegrees: bearing,
        cardinalDirection: cardinalDirectionFromDegrees(bearing),
        isArrived: arrived,
        isOfflineFallback: false,
        isFromCache: true,
        routeCoordinates: effectiveCoords,
      );
    }

    final String? token = accessToken;
    if (!isOnline || token == null || token.isEmpty) {
      return buildRouteSummary(origin, destination, travelMode: travelMode);
    }

    final http.Client effectiveClient = client ?? httpClient ?? http.Client();
    final bool shouldCloseClient = client == null && httpClient == null;

    final Uri uri = Uri.https(
      "api.mapbox.com",
      "/directions/v5/${travelMode.mapboxProfile}/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}",
      <String, String>{
        "geometries": "geojson",
        "overview": "full",
        "access_token": token,
      },
    );

    try {
      final http.Response response = await effectiveClient
          .get(uri)
          .timeout(kRouteApiTimeout);

      if (response.statusCode != 200) {
        return buildRouteSummary(origin, destination, travelMode: travelMode);
      }

      final Map<String, dynamic> json =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? routes = json["routes"] as List<dynamic>?;

      if (routes == null || routes.isEmpty) {
        return buildRouteSummary(origin, destination, travelMode: travelMode);
      }

      final Map<String, dynamic> route = routes.first as Map<String, dynamic>;
      final double distance = (route["distance"] as num).toDouble();
      final double duration = (route["duration"] as num).toDouble();
      final int minutes = (duration / 60).round().clamp(1, 1 << 30);

      final Map<String, dynamic>? geometry =
          route["geometry"] as Map<String, dynamic>?;
      final List<dynamic>? rawCoords = geometry?["coordinates"] as List<dynamic>?;

      final List<List<double>> coordinates = rawCoords != null
          ? rawCoords
              .map((dynamic coord) {
                final List<dynamic> pair = coord as List<dynamic>;
                return <double>[
                  (pair[0] as num).toDouble(),
                  (pair[1] as num).toDouble(),
                ];
              })
              .toList()
          : <List<double>>[
              <double>[origin.longitude, origin.latitude],
              <double>[destination.longitude, destination.latitude],
            ];

      // Salva no cache inteligente LRU para reutilizações subsequentes
      await cache.putRoute(
        originLat: origin.latitude,
        originLon: origin.longitude,
        destLat: destination.latitude,
        destLon: destination.longitude,
        travelMode: travelMode,
        distanceMeters: distance,
        estimatedMinutes: minutes,
        routeCoordinates: coordinates,
      );

      final double rawDirectDistance = distanceInMeters(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );

      final double bearing = bearingInDegrees(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );

      final bool arrived = rawDirectDistance <= kArrivalThresholdMeters;

      return RouteSummary(
        distanceMeters: arrived ? 0 : distance,
        estimatedMinutes: arrived ? 0 : minutes,
        travelMode: travelMode,
        bearingDegrees: bearing,
        cardinalDirection: cardinalDirectionFromDegrees(bearing),
        isArrived: arrived,
        isOfflineFallback: false,
        routeCoordinates: coordinates,
      );
    } catch (_) {
      return buildRouteSummary(origin, destination, travelMode: travelMode);
    } finally {
      if (shouldCloseClient) {
        effectiveClient.close();
      }
    }
  }

  /// Constrói o URI do aplicativo nativo de mapas.
  Uri buildNavigationUri(CollectionPoint point, {TargetPlatform? platform}) {
    final TargetPlatform target = platform ?? defaultTargetPlatform;
    final String coordinates = "${point.latitude},${point.longitude}";

    return switch (target) {
      TargetPlatform.android => Uri(
        scheme: "geo",
        path: coordinates,
        queryParameters: <String, String>{"q": "$coordinates(${point.name})"},
      ),
      TargetPlatform.iOS => Uri.https("maps.apple.com", "/", <String, String>{
        "daddr": coordinates,
        "q": point.name,
      }),
      _ => Uri.https("www.google.com", "/maps/dir/", <String, String>{
        "api": "1",
        "destination": coordinates,
      }),
    };
  }

  /// Abre o aplicativo nativo de mapas externo (ação opcional do usuário).
  Future<bool> openNavigation(
    CollectionPoint point, {
    TargetPlatform? platform,
  }) async {
    final Uri uri = buildNavigationUri(point, platform: platform);

    try {
      final UriLauncher? currentLauncher = launcher;
      if (currentLauncher != null) {
        return await currentLauncher(uri);
      }

      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
