/// El historial de conversaciones.
///
/// VALEN en el telefono se comporta como cualquier asistente al que estas
/// acostumbrado: **cada conversacion se queda guardada**, con su titulo, y
/// puedes volver a ella cuando quieras. Si el martes le mandaste la tarea de
/// fisica, el jueves sigue ahi.
///
/// DONDE SE GUARDA
///
/// En una base SQLite dentro del propio telefono. Es lo correcto aqui y no un
/// atajo: el historial se lee cada vez que abres la aplicacion y cada vez que
/// escribes, y hacer eso contra un servidor seria lento, gastaria datos y
/// dejaria de funcionar en cuanto te quedaras sin cobertura.
///
/// LAS IMAGENES
///
/// Las fotos no van dentro de la base de datos: se guardan como archivos y en
/// la base solo queda su ruta. Meter una foto de dos megas en cada fila haria
/// que la base creciera hasta hacerse lenta, y ademas asi Android puede
/// limpiarlas si algun dia hace falta sitio.
///
/// Al borrar una conversacion se borran tambien sus fotos, que si no se
/// quedarian ocupando sitio para siempre.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'sesion.dart';

/// Un mensaje de la conversacion, tuyo o de VALEN.
class Turno {
  Turno({
    this.id,
    required this.mio,
    required this.texto,
    this.rutasImagenes = const [],
    DateTime? cuando,
  }) : cuando = cuando ?? DateTime.now();

  final int? id;
  final bool mio;
  final String texto;
  final List<String> rutasImagenes;
  final DateTime cuando;

  bool get tieneImagenes => rutasImagenes.isNotEmpty;

  /// Lee las fotos del disco para volver a mandarselas al cerebro.
  Future<List<Uint8List>> leerImagenes() async {
    final datos = <Uint8List>[];
    for (final ruta in rutasImagenes) {
      final archivo = File(ruta);
      if (await archivo.exists()) datos.add(await archivo.readAsBytes());
    }
    return datos;
  }
}

/// Una conversacion entera.
class Conversacion {
  Conversacion({
    this.id,
    required this.titulo,
    DateTime? creada,
    DateTime? tocada,
  })  : creada = creada ?? DateTime.now(),
        tocada = tocada ?? DateTime.now();

  final int? id;
  String titulo;
  final DateTime creada;
  DateTime tocada;
}

class Historial {
  Historial._();
  static final Historial instancia = Historial._();

  Database? _bd;
  Directory? _carpetaFotos;

  /// El titulo se saca de lo primero que se dijo, recortado a esto.
  static const int largoDelTitulo = 42;

  /// La base, abriendola o reabriendola si hiciera falta.
  ///
  /// Nunca se da por buena la que hay guardada: Android puede cerrarla si va
  /// justo de memoria, y al cambiar de cuenta se cierra a proposito. Sin esta
  /// comprobacion, el objeto se quedaba con un manillar muerto y **todo lo que
  /// escribieras a partir de ahi se perdia**, sin un solo error a la vista.
  Future<Database> get _base async {
    if (_bd != null && _bd!.isOpen) return _bd!;

    _bd = await openDatabase(
      '${await getDatabasesPath()}/valen_historial.db',
      version: 1,
      onCreate: (bd, _) async {
        await bd.execute('''
          CREATE TABLE conversaciones (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario  TEXT NOT NULL DEFAULT '',
            titulo   TEXT NOT NULL,
            creada   TEXT NOT NULL,
            tocada   TEXT NOT NULL
          )
        ''');
        await bd.execute('''
          CREATE TABLE turnos (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            conversacion INTEGER NOT NULL,
            mio          INTEGER NOT NULL,
            texto        TEXT NOT NULL,
            imagenes     TEXT NOT NULL DEFAULT '[]',
            cuando       TEXT NOT NULL
          )
        ''');
        // Sin este indice, abrir una conversacion larga se nota.
        await bd.execute(
          'CREATE INDEX idx_turnos_conv ON turnos(conversacion, id)',
        );
      },
    );

    return _bd!;
  }

  /// A quien pertenecen las conversaciones. Sin cuenta, son del telefono.
  String get _duenoActual => Sesion.usuario?.id ?? '';

  /// Cierra la base. Se llama al cambiar de cuenta: la siguiente consulta la
  /// vuelve a abrir sola y ya con el usuario nuevo.
  Future<void> cerrar() async {
    if (_bd != null && _bd!.isOpen) await _bd!.close();
    _bd = null;
  }

  // -- conversaciones ------------------------------------------------------

  Future<List<Conversacion>> conversaciones({String buscar = ''}) async {
    final bd = await _base;

    final donde = StringBuffer('usuario = ?');
    final valores = <Object>[_duenoActual];

    if (buscar.trim().isNotEmpty) {
      // Busca en el titulo y tambien dentro de lo que se dijo, que es como
      // uno recuerda las cosas: "aquella vez que le pregunte por las derivadas".
      donde.write(
        ' AND (titulo LIKE ? OR id IN ('
        'SELECT conversacion FROM turnos WHERE texto LIKE ?))',
      );
      valores.addAll(['%${buscar.trim()}%', '%${buscar.trim()}%']);
    }

    final filas = await bd.query(
      'conversaciones',
      where: donde.toString(),
      whereArgs: valores,
      orderBy: 'tocada DESC',
    );

    return filas
        .map((f) => Conversacion(
              id: f['id'] as int,
              titulo: f['titulo'] as String,
              creada: DateTime.parse(f['creada'] as String),
              tocada: DateTime.parse(f['tocada'] as String),
            ))
        .toList();
  }

  Future<Conversacion> nueva({String titulo = 'Conversacion nueva'}) async {
    final bd = await _base;
    final ahora = DateTime.now();

    final id = await bd.insert('conversaciones', {
      'usuario': _duenoActual,
      'titulo': titulo,
      'creada': ahora.toIso8601String(),
      'tocada': ahora.toIso8601String(),
    });

    return Conversacion(id: id, titulo: titulo, creada: ahora, tocada: ahora);
  }

  Future<void> renombrar(int id, String titulo) async {
    final bd = await _base;
    await bd.update(
      'conversaciones',
      {'titulo': titulo.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> borrar(int id) async {
    final bd = await _base;

    // Las fotos primero: si se borra la fila antes, se pierden las rutas y
    // los archivos se quedan ocupando sitio para siempre.
    for (final turno in await turnos(id)) {
      for (final ruta in turno.rutasImagenes) {
        try {
          await File(ruta).delete();
        } catch (_) {}
      }
    }

    await bd.delete('turnos', where: 'conversacion = ?', whereArgs: [id]);
    await bd.delete('conversaciones', where: 'id = ?', whereArgs: [id]);
  }

  // -- turnos --------------------------------------------------------------

  Future<List<Turno>> turnos(int conversacion) async {
    final bd = await _base;

    final filas = await bd.query(
      'turnos',
      where: 'conversacion = ?',
      whereArgs: [conversacion],
      orderBy: 'id ASC',
    );

    return filas.map((f) {
      final rutas = (jsonDecode(f['imagenes'] as String) as List).cast<String>();
      return Turno(
        id: f['id'] as int,
        mio: (f['mio'] as int) == 1,
        texto: f['texto'] as String,
        rutasImagenes: rutas,
        cuando: DateTime.parse(f['cuando'] as String),
      );
    }).toList();
  }

  Future<Turno> anotar(
    int conversacion, {
    required bool mio,
    required String texto,
    List<Uint8List> imagenes = const [],
  }) async {
    final bd = await _base;

    final rutas = <String>[];
    for (final imagen in imagenes) {
      rutas.add(await _guardarFoto(imagen));
    }

    final ahora = DateTime.now();
    final id = await bd.insert('turnos', {
      'conversacion': conversacion,
      'mio': mio ? 1 : 0,
      'texto': texto,
      'imagenes': jsonEncode(rutas),
      'cuando': ahora.toIso8601String(),
    });

    await bd.update(
      'conversaciones',
      {'tocada': ahora.toIso8601String()},
      where: 'id = ?',
      whereArgs: [conversacion],
    );

    return Turno(
      id: id,
      mio: mio,
      texto: texto,
      rutasImagenes: rutas,
      cuando: ahora,
    );
  }

  /// Le pone titulo a una conversacion segun lo primero que se pregunto.
  ///
  /// Es lo que hace que la lista se pueda leer de un vistazo en vez de ser
  /// veinte filas que ponen "Conversacion nueva".
  Future<String> titularSegunLoPrimero(int conversacion, String primerTexto,
      {bool teniaFotos = false}) async {
    var titulo = primerTexto.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (titulo.isEmpty && teniaFotos) {
      titulo = 'Tarea del ${DateTime.now().day}/${DateTime.now().month}';
    }
    if (titulo.isEmpty) {
      titulo = 'Conversacion nueva';
    }
    if (titulo.length > largoDelTitulo) {
      // Se corta por la ultima palabra entera, no a mitad de una.
      final recorte = titulo.substring(0, largoDelTitulo);
      final espacio = recorte.lastIndexOf(' ');
      titulo = '${espacio > 12 ? recorte.substring(0, espacio) : recorte}...';
    }

    await renombrar(conversacion, titulo);
    return titulo;
  }

  // -- fotos ---------------------------------------------------------------

  Future<String> _guardarFoto(Uint8List datos) async {
    _carpetaFotos ??= Directory(
      '${(await getApplicationDocumentsDirectory()).path}/valen_fotos',
    );

    if (!await _carpetaFotos!.exists()) {
      await _carpetaFotos!.create(recursive: true);
    }

    final nombre = '${DateTime.now().microsecondsSinceEpoch}.jpg';
    final archivo = File('${_carpetaFotos!.path}/$nombre');
    await archivo.writeAsBytes(datos);

    return archivo.path;
  }

  /// Cuanto ocupan las fotos guardadas, para poder decirlo en los ajustes.
  Future<int> megasDeFotos() async {
    _carpetaFotos ??= Directory(
      '${(await getApplicationDocumentsDirectory()).path}/valen_fotos',
    );

    if (!await _carpetaFotos!.exists()) return 0;

    var bytes = 0;
    await for (final archivo in _carpetaFotos!.list()) {
      if (archivo is File) bytes += await archivo.length();
    }

    return bytes ~/ (1024 * 1024);
  }
}
