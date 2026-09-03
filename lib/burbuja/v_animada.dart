/// La V de VALEN, viva.
///
/// Es la cara de la aplicacion en el telefono. En vez de abrir una pantalla
/// entera para hablarle, la V flota encima de lo que estes haciendo y **cambia
/// segun lo que este haciendo VALEN**, igual que el asistente del iPhone: se
/// nota de un vistazo si te esta oyendo, si esta pensando o si esta hablando.
///
/// Cada estado tiene su gesto propio:
///
/// - dormido:    respira despacio, apagada. No llama la atencion.
/// - escuchando: se abre, y el aura sigue el volumen de tu voz de verdad.
/// - pensando:   un arco gira a su alrededor, como buscando.
/// - hablando:   salen ondas de la V, al ritmo de lo que dice.
/// - error:      un latido rojo corto.
///
/// Todo se dibuja con vectores sobre un lienzo, asi que se ve nitida lo mismo
/// en la burbuja de sesenta pixeles que a pantalla completa.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../nucleo/estados.dart';
import '../nucleo/logo.dart';

class VAnimada extends StatefulWidget {
  const VAnimada({
    super.key,
    required this.estado,
    this.lado = 120,
    this.nivelVoz = 0.0,
  });

  final EstadoValen estado;
  final double lado;

  /// Cuanto suena la voz ahora mismo, de 0 a 1. Solo se usa escuchando y
  /// hablando: es lo que hace que el aura siga a la persona de verdad en vez
  /// de moverse sola sin ton ni son.
  final double nivelVoz;

  @override
  State<VAnimada> createState() => _VAnimadaState();
}

class _VAnimadaState extends State<VAnimada> with SingleTickerProviderStateMixin {
  late final AnimationController _reloj;

  // El color y el brillo no saltan de golpe al cambiar de estado: se van
  // acercando poco a poco al del estado nuevo. Un corte seco se ve barato.
  Color _color = EstadoValen.dormido.color;
  double _brillo = EstadoValen.dormido.brillo;
  double _nivelSuave = 0.0;

  @override
  void initState() {
    super.initState();
    _reloj = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _color = widget.estado.color;
    _brillo = widget.estado.brillo;
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reloj,
      builder: (context, _) {
        // Suavizado exponencial: cada cuadro se acerca un poco al objetivo.
        _color = Color.lerp(_color, widget.estado.color, 0.06)!;
        _brillo += (widget.estado.brillo - _brillo) * 0.06;
        _nivelSuave += (widget.nivelVoz.clamp(0.0, 1.0) - _nivelSuave) * 0.25;

        return SizedBox(
          width: widget.lado,
          height: widget.lado,
          child: CustomPaint(
            painter: _PintorV(
              tiempo: _reloj.value * 8,
              estado: widget.estado,
              color: _color,
              brillo: _brillo,
              nivelVoz: _nivelSuave,
            ),
          ),
        );
      },
    );
  }
}

class _PintorV extends CustomPainter {
  _PintorV({
    required this.tiempo,
    required this.estado,
    required this.color,
    required this.brillo,
    required this.nivelVoz,
  });

  final double tiempo;
  final EstadoValen estado;
  final Color color;
  final double brillo;
  final double nivelVoz;

  @override
  void paint(Canvas lienzo, Size medida) {
    final centro = Offset(medida.width / 2, medida.height / 2);
    final radio = medida.width / 2;
    final fase = tiempo * estado.ritmo * 2 * math.pi;
    final latido = (math.sin(fase) + 1) / 2; // 0..1

    _pintarHalo(lienzo, centro, radio, latido);

    switch (estado) {
      case EstadoValen.escuchando:
        _pintarAuraDeVoz(lienzo, centro, radio);
      case EstadoValen.pensando:
        _pintarArcoQueGira(lienzo, centro, radio);
      case EstadoValen.hablando:
        _pintarOndas(lienzo, centro, radio);
      case EstadoValen.dormido:
      case EstadoValen.error:
        break;
    }

    _pintarLaV(lienzo, medida, latido);
  }

  /// El resplandor de detras, que da el color al conjunto.
  void _pintarHalo(Canvas lienzo, Offset centro, double radio, double latido) {
    final intensidad = brillo * (0.75 + latido * 0.25);
    final pincel = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.55 * intensidad),
          color.withValues(alpha: 0.16 * intensidad),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: centro, radius: radio));

    lienzo.drawCircle(centro, radio, pincel);
  }

  /// Escuchando: dos anillos que crecen con tu voz.
  void _pintarAuraDeVoz(Canvas lienzo, Offset centro, double radio) {
    for (var i = 0; i < 2; i++) {
      final base = 0.62 + i * 0.13;
      final empuje = nivelVoz * (0.20 - i * 0.06);
      final pincel = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radio * (0.035 - i * 0.012)
        ..color = color.withValues(alpha: (0.5 - i * 0.18) * (0.35 + nivelVoz * 0.65));

      lienzo.drawCircle(centro, radio * (base + empuje), pincel);
    }
  }

  /// Pensando: un arco que da vueltas, como buscando la respuesta.
  void _pintarArcoQueGira(Canvas lienzo, Offset centro, double radio) {
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radio * 0.04
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [Colors.transparent, color.withValues(alpha: 0.9), Colors.transparent],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(tiempo * 3.2),
      ).createShader(Rect.fromCircle(center: centro, radius: radio * 0.78));

    lienzo.drawCircle(centro, radio * 0.78, pincel);
  }

  /// Hablando: ondas que salen de la V y se desvanecen.
  void _pintarOndas(Canvas lienzo, Offset centro, double radio) {
    const cuantas = 3;
    for (var i = 0; i < cuantas; i++) {
      // Cada onda va desfasada, para que salgan una detras de otra.
      final avance = ((tiempo * 0.9 + i / cuantas) % 1.0);
      final tamano = radio * (0.55 + avance * 0.62);
      final desvanece = (1 - avance) * (0.35 + nivelVoz * 0.65);

      final pincel = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radio * 0.03 * (1 - avance)
        ..color = color.withValues(alpha: 0.55 * desvanece);

      lienzo.drawCircle(centro, tamano, pincel);
    }
  }

  /// La V en si, centrada y con el borde encendido.
  void _pintarLaV(Canvas lienzo, Size medida, double latido) {
    // Escuchando la V se abre un poco; pensando se encoge. Es sutil a
    // proposito: se nota sin resultar payaso.
    final apertura = switch (estado) {
      EstadoValen.escuchando => 1.0 + nivelVoz * 0.06,
      EstadoValen.pensando => 0.95,
      EstadoValen.hablando => 1.0 + latido * 0.035,
      EstadoValen.error => 1.0 + latido * 0.08,
      EstadoValen.dormido => 0.97 + latido * 0.02,
    };

    final anchoV = medida.width * 0.52 * apertura;
    final trazado = trazadoV(anchoV);
    final alto = altoV(anchoV);

    lienzo.save();
    lienzo.translate(
      (medida.width - anchoV) / 2,
      (medida.height - alto) / 2,
    );

    // Relleno con un degradado vertical, mas claro arriba.
    final relleno = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(color, Colors.white, 0.45)!,
          color,
        ],
      ).createShader(Rect.fromLTWH(0, 0, anchoV, alto));

    lienzo.drawPath(trazado, relleno);

    // Borde encendido: es lo que la hace parecer viva y no un dibujo pegado.
    final borde = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = anchoV * 0.012
      ..color = Color.lerp(color, Colors.white, 0.7)!
          .withValues(alpha: 0.35 + latido * 0.45);

    lienzo.drawPath(trazado, borde);
    lienzo.restore();
  }

  @override
  bool shouldRepaint(_PintorV anterior) => true;
}
