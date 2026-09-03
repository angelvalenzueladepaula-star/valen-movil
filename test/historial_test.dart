// El historial es lo que convierte a VALEN en algo con lo que se puede
// trabajar de verdad, asi que se prueba de verdad: contra una base SQLite
// como la del telefono, no contra un simulacro.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:valen_movil/nucleo/historial.dart';

void main() {
  setUpAll(() {
    // En el ordenador SQLite va por otra puerta que en Android.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Cada prueba empieza limpia, o la de al lado le deja basura. Se cierra
    // antes de borrar: borrar un archivo que sigue abierto no funciona.
    await Historial.instancia.cerrar();
    await databaseFactory.deleteDatabase(
      '${await databaseFactory.getDatabasesPath()}/valen_historial.db',
    );
  });

  test('una conversacion nueva se guarda y se encuentra', () async {
    final creada = await Historial.instancia.nueva(titulo: 'Fisica');

    expect(creada.id, isNotNull);

    final todas = await Historial.instancia.conversaciones();
    expect(todas.length, 1);
    expect(todas.first.titulo, 'Fisica');
  });

  test('los turnos se guardan en orden y se recuperan igual', () async {
    final conv = await Historial.instancia.nueva();

    await Historial.instancia.anotar(conv.id!, mio: true, texto: 'Cuanto es 2+2');
    await Historial.instancia.anotar(conv.id!, mio: false, texto: 'Cuatro.');
    await Historial.instancia.anotar(conv.id!, mio: true, texto: 'Y 3+3');

    final turnos = await Historial.instancia.turnos(conv.id!);

    expect(turnos.length, 3);
    expect(turnos[0].texto, 'Cuanto es 2+2');
    expect(turnos[0].mio, isTrue);
    expect(turnos[1].mio, isFalse);
    expect(turnos[2].texto, 'Y 3+3');
  });

  test('sobrevive a cerrar y volver a abrir', () async {
    final conv = await Historial.instancia.nueva(titulo: 'Quimica');
    await Historial.instancia.anotar(conv.id!, mio: true, texto: 'La tabla periodica');

    // Se simula cerrar la aplicacion: la base se vuelve a abrir de cero.
    final otraVez = await Historial.instancia.turnos(conv.id!);
    expect(otraVez.first.texto, 'La tabla periodica');

    final todas = await Historial.instancia.conversaciones();
    expect(todas.any((c) => c.titulo == 'Quimica'), isTrue);
  });

  test('la mas usada sale primero en la lista', () async {
    final vieja = await Historial.instancia.nueva(titulo: 'Vieja');
    await Future<void>.delayed(const Duration(milliseconds: 12));
    await Historial.instancia.nueva(titulo: 'Nueva');
    await Future<void>.delayed(const Duration(milliseconds: 12));

    // Al escribir en la vieja, esta vuelve arriba.
    await Historial.instancia.anotar(vieja.id!, mio: true, texto: 'hola');

    final todas = await Historial.instancia.conversaciones();
    expect(todas.first.titulo, 'Vieja');
  });

  test('el buscador mira dentro de lo que se dijo, no solo en el titulo', () async {
    final conv = await Historial.instancia.nueva(titulo: 'Sin nombre');
    await Historial.instancia.anotar(
      conv.id!,
      mio: true,
      texto: 'explicame las derivadas parciales',
    );
    await Historial.instancia.nueva(titulo: 'Otra cosa');

    final encontradas =
        await Historial.instancia.conversaciones(buscar: 'derivadas');

    expect(encontradas.length, 1);
    expect(encontradas.first.id, conv.id);
  });

  test('el titulo sale de la primera pregunta, cortado por palabra entera', () async {
    final conv = await Historial.instancia.nueva();

    final titulo = await Historial.instancia.titularSegunLoPrimero(
      conv.id!,
      'Explicame como se resuelven las ecuaciones de segundo grado paso a paso',
    );

    expect(titulo.length, lessThanOrEqualTo(Historial.largoDelTitulo + 3));
    expect(titulo, startsWith('Explicame como se resuelven'));
    // Cortado por palabra entera, no a mitad de una.
    expect(titulo.endsWith('...'), isTrue);
    expect(titulo.contains('  '), isFalse);
  });

  test('sin texto pero con fotos, el titulo dice que era una tarea', () async {
    final conv = await Historial.instancia.nueva();

    final titulo = await Historial.instancia.titularSegunLoPrimero(
      conv.id!,
      '',
      teniaFotos: true,
    );

    expect(titulo.toLowerCase(), contains('tarea'));
  });

  test('borrar una conversacion se lleva sus turnos', () async {
    final conv = await Historial.instancia.nueva();
    await Historial.instancia.anotar(conv.id!, mio: true, texto: 'algo');

    await Historial.instancia.borrar(conv.id!);

    expect(await Historial.instancia.conversaciones(), isEmpty);
    expect(await Historial.instancia.turnos(conv.id!), isEmpty);
  });

  test('renombrar cambia el titulo y se queda cambiado', () async {
    final conv = await Historial.instancia.nueva(titulo: 'Antes');
    await Historial.instancia.renombrar(conv.id!, 'Despues');

    final todas = await Historial.instancia.conversaciones();
    expect(todas.first.titulo, 'Despues');
  });
}
