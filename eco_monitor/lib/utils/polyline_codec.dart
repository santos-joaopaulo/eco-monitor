// Methods ------------------------------------------------------------------ //


/// Decodifica uma polilinha no formato Google Polyline Algorithm (fator 1e5)
/// retornando uma lista de pares de coordenadas `[longitude, latitude]`.
List<List<double>> decodePolyline(String encoded) {
  if (encoded.isEmpty) {
    return const <List<double>>[];
  }

  final List<List<double>> coordinates = <List<double>>[];
  int index = 0;
  final int len = encoded.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int b;
    int shift = 0;
    int result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    coordinates.add(<double>[lng / 1e5, lat / 1e5]);
  }

  return coordinates;
}

/// Codifica uma lista de coordenadas `[longitude, latitude]` no formato
/// padrão Google Polyline Algorithm (fator 1e5).
String encodePolyline(List<List<double>> coordinates) {
  if (coordinates.isEmpty) {
    return "";
  }

  final StringBuffer buffer = StringBuffer();
  int prevLat = 0;
  int prevLng = 0;

  for (final List<double> coord in coordinates) {
    final int latInt = (coord[1] * 1e5).round();
    final int lngInt = (coord[0] * 1e5).round();

    final int dLat = latInt - prevLat;
    final int dLng = lngInt - prevLng;

    prevLat = latInt;
    prevLng = lngInt;

    _encodeSignedInt(dLat, buffer);
    _encodeSignedInt(dLng, buffer);
  }

  return buffer.toString();
}

void _encodeSignedInt(int value, StringBuffer buffer) {
  int s = value << 1;
  if (value < 0) {
    s = ~s;
  }
  while (s >= 0x20) {
    buffer.writeCharCode((0x20 | (s & 0x1f)) + 63);
    s >>= 5;
  }
  buffer.writeCharCode(s + 63);
}
