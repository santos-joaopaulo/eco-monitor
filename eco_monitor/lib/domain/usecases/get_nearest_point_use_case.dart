import "../../utils/geo.dart";
import "../entities/collection_point.dart";
import "../entities/waste_type.dart";


// Types ------------------------------------------------------------------- //


/// Resultado do cálculo do ponto mais próximo.
class NearestPointResult {
  const NearestPointResult({
    required this.point,
    required this.distanceMeters,
  });

  final CollectionPoint point;
  final double distanceMeters;
}


// Use cases --------------------------------------------------------------- //


/// Caso de uso para localizar o ponto de coleta mais próximo do usuário (Domínio).
class GetNearestPointUseCase {
  const GetNearestPointUseCase();

  /// Encontra o ecoponto ativo mais próximo das coordenadas do usuário.
  NearestPointResult? execute({
    required double userLatitude,
    required double userLongitude,
    required List<CollectionPoint> points,
    Set<WasteType> selectedWasteTypes = const <WasteType>{},
    double? maxDistanceMeters,
  }) {
    CollectionPoint? nearest;
    double minDistance = double.infinity;

    for (final CollectionPoint point in points) {
      if (!point.isActive) {
        continue;
      }
      if (selectedWasteTypes.isNotEmpty && !point.acceptsAny(selectedWasteTypes)) {
        continue;
      }

      final double dist = distanceInMeters(
        userLatitude,
        userLongitude,
        point.latitude,
        point.longitude,
      );

      if (maxDistanceMeters != null && dist > maxDistanceMeters) {
        continue;
      }

      if (dist < minDistance) {
        minDistance = dist;
        nearest = point;
      }
    }

    if (nearest == null) {
      return null;
    }

    return NearestPointResult(point: nearest, distanceMeters: minDistance);
  }
}
