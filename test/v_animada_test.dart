// Comprobaciones de la V: que el trazado sale bien y que cada estado se ve
// distinto. Sin esto, un fallo en las coordenadas solo se veria mirando.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valen_movil/burbuja/v_animada.dart';
import 'package:valen_movil/nucleo/cerebro.dart';
import 'package:valen_movil/nucleo/estados.dart';
import 'package:valen_movil/nucleo/logo.dart';

void main() {
  test('la silueta tiene pares completos de coordenadas', () {
    expect(siluetaV.length.isEven, isTrue);
    expect(siluetaV.length ~/ 2, greaterThan(20));
  });

  test('todas las coordenadas caen dentro del cuadro 0..1', () {
    for (final valor in siluetaV) {
      expect(valor, inInclusiveRange(0.0, 1.0));
    }
  });

  test('el trazado ocupa casi todo el ancho que se le pide', () {
    final caja = trazadoV(100).getBounds();
    expect(caja.width, closeTo(100, 2));
    expect(caja.height, greaterThan(60));
  });

  test('la V es mas ancha que alta, como el logo', () {
    expect(altoV(100), lessThan(100));
    expect(altoV(100), greaterThan(50));
  });

  test('cada estado tiene su color, su brillo y su ritmo', () {
    final colores = EstadoValen.values.map((e) => e.color).toSet();
    expect(colores.length, EstadoValen.values.length);

    expect(EstadoValen.dormido.brillo, lessThan(EstadoValen.hablando.brillo));
    expect(EstadoValen.dormido.ritmo, lessThan(EstadoValen.pensando.ritmo));
  });

  testWidgets('la V se dibuja y no revienta al cambiar de estado', (tester) async {
    for (final estado in EstadoValen.values) {
      await tester.pumpWidget(MaterialApp(
        home: Center(child: VAnimada(estado: estado, lado: 120, nivelVoz: 0.5)),
      ));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(VAnimada), findsOneWidget);
    }
  });

  test('los cuatro modos de tarea dicen cosas distintas', () {
    final conInstruccion = ModoTarea.values
        .where((m) => m != ModoTarea.normal)
        .toList();

    // Cada boton tiene que pedirle algo diferente al modelo, o sobra.
    final instrucciones = conInstruccion.map((m) => m.instruccion).toSet();
    expect(instrucciones.length, conInstruccion.length);

    for (final modo in conInstruccion) {
      expect(modo.instruccion, isNotEmpty);
      expect(modo.etiqueta, isNotEmpty);
    }

    // El modo normal no mete nada en el prompt: es conversacion a secas.
    expect(ModoTarea.normal.instruccion, isEmpty);
  });
}
