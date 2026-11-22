import "dart:typed_data";
import "dart:ui" as ui;

import "package:material_ui/material_ui.dart";

import "../models/collection_point.dart";
import "../theme/app_colors.dart";


// Classes ----------------------------------------------------------------- //


/// Marcador de ponto de coleta renderizado em tempo de execução como PNG para anotações do Mapbox.
///
/// Todo marcador utiliza [AppColors.primary] como cor de base. O tipo é indicado
/// pelo distintivo interno: farmácia utiliza [AppColors.medicine] com ícone de farmácia,
/// UBS utiliza [AppColors.userLocation] com ícone de hospital e ecoponto utiliza
/// [AppColors.battery] com ícone de reciclagem.
abstract final class PointPin {
  static const int _width = 96;
  static const int _height = 128;


  // Methods --------------------------------------------------------------- //


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
}


// Methods ----------------------------------------------------------------- //


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
