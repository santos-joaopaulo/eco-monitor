import "../models/collection_point.dart";

// Methods ----------------------------------------------------------------- //

/// Points shown on the map for the current waste selection.
///
/// Inactive points are never shown. An empty selection means "all residues",
/// otherwise the point must accept at least one of the selected types.
List<CollectionPoint> filterCollectionPoints(
  List<CollectionPoint> points,
  Set<WasteType> selectedWasteTypes,
) {
  return points
      .where(
        (CollectionPoint point) =>
            point.isActive && point.acceptsAny(selectedWasteTypes),
      )
      .toList();
}
