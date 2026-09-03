/// Lo que VALEN va aprendiendo de quien lo usa.
///
/// Misma idea que en el escritorio, con dos diferencias que impone el telefono:
///
/// - **Cada usuario tiene la suya.** La aplicacion la puede instalar
///   cualquiera, asi que lo que VALEN sabe de ti va atado a tu cuenta y no lo
///   ve nadie mas. Lo garantiza la regla por fila del servidor, no el codigo
///   de aqui: si alguien manipula la aplicacion, el servidor sigue diciendo
///   que no.
/// - **Funciona sin conexion.** Un telefono se queda sin datos a cada rato.
///   Todo se guarda tambien en el propio aparato y sube cuando hay red, igual
///   que hace la copia local de la version de escritorio.
///
/// De momento no hay busqueda por significado con embeddings: en el telefono
/// cada consulta cuesta bateria y cuota, y con los pocos recuerdos que se
/// acumulan al principio, buscar por palabras da casi lo mismo. Se anadira
/// cuando la memoria de alguien crezca lo suficiente para notarlo.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sesion.dart';

class Hecho {
  const Hecho({
    required this.clave,
    required this.valor,
    this.confianza = 0.8,
  });

  final String clave;
  final String valor;
  final double confianza;

  Map<String, dynamic> aMapa() => {
        'clave': clave,
        'valor': valor,
        'confianza': confianza,
      };

  static Hecho deMapa(Map<String, dynamic> m) => Hecho(
        clave: m['clave'] as String,
        valor: m['valor'] as String,
        confianza: (m['confianza'] as num?)?.toDouble() ?? 0.8,
      );
}

class Memoria {
  Memoria._();
  static final Memoria instancia = Memoria._();

  static const int maxHechosEnPrompt = 30;

  SharedPreferences? _local;
  List<Hecho> _hechos = [];
  bool _cargada = false;

  String get _cajonLocal => 'hechos_${Sesion.usuario?.id ?? "invitado"}';

  Future<void> cargar() async {
    _local ??= await SharedPreferences.getInstance();

    // Primero lo del propio telefono, que es instantaneo y siempre esta.
    final guardado = _local!.getString(_cajonLocal);
    if (guardado != null) {
      final lista = jsonDecode(guardado) as List;
      _hechos = lista.map((m) => Hecho.deMapa(m as Map<String, dynamic>)).toList();
    }

    _cargada = true;
    await _bajarDeLaNube();
  }

  Future<void> _bajarDeLaNube() async {
    if (!Sesion.haEntrado) return;

    try {
      final filas = await Supabase.instance.client
          .from('hechos')
          .select('clave, valor, confianza')
          .order('actualizado', ascending: false)
          .limit(200);

      if (filas.isNotEmpty) {
        _hechos = filas
            .map((m) => Hecho.deMapa(Map<String, dynamic>.from(m as Map)))
            .toList();
        await _guardarLocal();
      }
    } catch (_) {
      // Sin red se sigue con lo que hay en el telefono. No es un error que
      // merezca molestar al usuario.
    }
  }

  Future<void> _guardarLocal() async {
    await _local?.setString(
      _cajonLocal,
      jsonEncode(_hechos.map((h) => h.aMapa()).toList()),
    );
  }

  // -- lo que se usa desde fuera -------------------------------------------

  List<Hecho> get hechos => List.unmodifiable(_hechos);

  Future<void> aprender(String clave, String valor, {double confianza = 0.8}) async {
    if (!_cargada) await cargar();

    final normalizada = clave.trim().toLowerCase();
    if (normalizada.isEmpty || valor.trim().isEmpty) return;

    _hechos.removeWhere((h) => h.clave == normalizada);
    _hechos.insert(0, Hecho(clave: normalizada, valor: valor.trim(), confianza: confianza));

    await _guardarLocal();

    if (!Sesion.haEntrado) return;

    try {
      await Supabase.instance.client.from('hechos').upsert({
        'usuario': Sesion.usuario!.id,
        'clave': normalizada,
        'valor': valor.trim(),
        'confianza': confianza,
        'actualizado': DateTime.now().toIso8601String(),
      }, onConflict: 'usuario,clave');
    } catch (_) {
      // Queda en el telefono; subira la proxima vez que se lea la nube.
    }
  }

  Future<void> olvidar(String clave) async {
    final normalizada = clave.trim().toLowerCase();
    _hechos.removeWhere((h) => h.clave == normalizada);
    await _guardarLocal();

    if (!Sesion.haEntrado) return;

    try {
      await Supabase.instance.client
          .from('hechos')
          .delete()
          .match({'usuario': Sesion.usuario!.id, 'clave': normalizada});
    } catch (_) {}
  }

  /// El bloque que se le cuela al cerebro para que sepa con quien habla.
  Future<String> contextoParaPrompt() async {
    if (!_cargada) await cargar();
    if (_hechos.isEmpty) return '';

    final lineas = _hechos.take(maxHechosEnPrompt).map((h) {
      // Lo dudoso se marca, para que VALEN no lo afirme como si fuera seguro.
      final duda = h.confianza < 0.6 ? ' (no estoy seguro)' : '';
      return '- ${h.clave}: ${h.valor}$duda';
    });

    return 'Lo que ya sabes de ${Sesion.nombre}, de conversaciones anteriores:\n'
        '${lineas.join('\n')}\n'
        'Usalo con naturalidad, sin recitarlo ni decir que lo tienes anotado.';
  }

  /// Al cambiar de usuario se vacia todo lo que habia en memoria viva.
  void reiniciar() {
    _hechos = [];
    _cargada = false;
  }
}
