import "dart:typed_data";
import "dart:ui" as ui;

import "package:material_ui/material_ui.dart";

import "../domain/entities/collection_point.dart";
import "../theme/app_colors.dart";


// Classes ------------------------------------------------------------------ //


/// Marcador de ponto de coleta renderizado em tempo de execução como PNG para anotações do Mapbox.
///
/// Todo marcador utiliza [AppColors.primary] como cor de base. O tipo é indicado
/// pelo distintivo interno: farmácia utiliza [AppColors.medicine] com ícone de farmácia,
/// UBS utiliza [AppColors.userLocation] com ícone de hospital e ecoponto utiliza
/// [AppColors.battery] com ícone de reciclagem.
abstract final class PointPin {
  static const int _width = 96;
  static const int _height = 128;


// Methods ------------------------------------------------------------------ //


  static Future<Uint8List> render({
    required PointType type,
    bool selected = false,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Color baseColor = AppColors.primary;

    final double width = _width.toDouble();
    final double height = _height.toDouble();
    final double centerX = width / 2;
    final double headCenterY = 46;
    final double headRadius = 38;
    final double tipY = height - 6;

    final Path head = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(centerX, headCenterY),
          radius: headRadius,
        ),
      );

    final Path tail = Path()
      ..moveTo(centerX - headRadius * 0.58, headCenterY + headRadius * 0.7)
      ..lineTo(centerX, tipY)
      ..lineTo(centerX + headRadius * 0.58, headCenterY + headRadius * 0.7)
      ..close();

    final Path pin = Path.combine(PathOperation.union, head, tail);

    canvas.drawShadow(
      pin,
      Colors.black.withAlpha(selected ? 110 : 85),
      selected ? 7 : 5,
      true,
    );

    final Paint fillPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = baseColor;
    canvas.drawPath(pin, fillPaint);

    final Paint borderPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 5.5 : 4.5
      ..color = Colors.white;
    canvas.drawPath(pin, borderPaint);

    final Offset holeCenter = Offset(centerX, headCenterY);
    canvas.drawCircle(
      holeCenter,
      headRadius * 0.48,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      holeCenter,
      headRadius * 0.39,
      Paint()..color = _badgeColor(type),
    );

    _paintBadgeIcon(canvas, holeCenter, _badgeIcon(type), headRadius * 0.36);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(_width, _height);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    picture.dispose();

    return data!.buffer.asUint8List();
  }

  static final Map<int, Uint8List> _clusterCache = <int, Uint8List>{};

  /// Renderiza uma bolha circular estilizada com a contagem de pontos acumulados para clusters do Mapbox (T11.2).
  static Future<Uint8List> renderCluster({required int count}) async {
    final Uint8List? cached = _clusterCache[count];
    if (cached != null) {
      return cached;
    }

    const int size = 80;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    const double center = size / 2.0;
    const double radius = 32.0;
    const Offset centerOffset = Offset(center, center);

    // Sombra suave
    final Path circlePath = Path()
      ..addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    canvas.drawShadow(circlePath, Colors.black.withAlpha(90), 6.0, true);

    // Fundo circular AppColors.primaryAccessible (WCAG AA alto contraste)
    final Paint fillPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = AppColors.primaryAccessible;
    canvas.drawCircle(centerOffset, radius, fillPaint);

    // Borda branca contrastante
    final Paint borderPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = Colors.white;
    canvas.drawCircle(centerOffset, radius, borderPaint);

    // Texto com a contagem acumulada
    final String label = count > 99 ? "99+" : count.toString();
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: label.length > 2 ? 18.0 : 22.0,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      centerOffset - Offset(painter.width / 2.0, painter.height / 2.0),
    );
    painter.dispose();

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(size, size);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    picture.dispose();

    final Uint8List bytes = data!.buffer.asUint8List();
    _clusterCache[count] = bytes;
    return bytes;
  }

  static final Map<bool, Uint8List> _campaignCache = <bool, Uint8List>{};

  /// Renderiza o marcador circular exclusivo para eventos e campanhas no mapa (44x44 dp).
  static Future<Uint8List> renderCampaign({bool selected = false}) async {
    final Uint8List? cached = _campaignCache[selected];
    if (cached != null) {
      return cached;
    }

    const int size = 44;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    const double center = size / 2.0;
    const double radius = 18.0;
    const Offset centerOffset = Offset(center, center);

    // Sombra suave circular projetada
    final Path circlePath = Path()
      ..addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    canvas.drawShadow(
      circlePath,
      Colors.black.withAlpha(selected ? 110 : 80),
      selected ? 4.0 : 3.0,
      true,
    );

    // Fundo circular com cor primária AppColors.primary
    final Paint fillPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = AppColors.primary;
    canvas.drawCircle(centerOffset, radius, fillPaint);

    // Anel e borda externa branca de 3 dp
    final Paint borderPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.white;
    canvas.drawCircle(centerOffset, radius, borderPaint);

    // Ícone temático Icons.event_available em branco no centro
    const IconData icon = Icons.event_available_rounded;
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 20.0,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      centerOffset - Offset(painter.width / 2.0, painter.height / 2.0),
    );
    painter.dispose();

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(size, size);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    picture.dispose();

    final Uint8List bytes = data!.buffer.asUint8List();
    _campaignCache[selected] = bytes;
    return bytes;
  }
}


// Methods ------------------------------------------------------------------ //


Color _badgeColor(PointType type) {
  return switch (type) {
    PointType.pharmacy => AppColors.medicine,
    PointType.healthCenter => AppColors.userLocation,
    PointType.ecoPoint => AppColors.battery,
  };
}

IconData _badgeIcon(PointType type) {
  return switch (type) {
    PointType.pharmacy => Icons.local_pharmacy_rounded,
    PointType.healthCenter => Icons.local_hospital_rounded,
    PointType.ecoPoint => Icons.recycling_rounded,
  };
}

void _paintBadgeIcon(
  Canvas canvas,
  Offset center,
  IconData icon,
  double radius,
) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: radius * 1.5,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  painter.dispose();
}
