/// Lo que el usuario configura una vez y VALEN recuerda.
///
/// Las claves van al llavero cifrado de Android (`flutter_secure_storage`), no
/// a las preferencias normales: una clave de API en texto plano dentro del
/// telefono es un regalo para cualquier aplicacion que sepa mirar.
///
/// El resto de ajustes, que no son secretos, van a las preferencias de toda la
/// vida porque se leen constantemente y ahi es instantaneo.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Ajustes {
  // Android ya cifra por su cuenta; el parametro que habia aqui esta
  // descatalogado y se ignora.
  static const _llavero = FlutterSecureStorage();

  static late SharedPreferences _prefs;
  static String _claveGemini = '';

  /// Se llama una vez al arrancar, antes de usar nada de aqui.
  static Future<void> cargar() async {
    _prefs = await SharedPreferences.getInstance();
    _claveGemini = await _llavero.read(key: 'clave_gemini') ?? '';
  }

  // -- la clave del cerebro ------------------------------------------------

  static String get claveGemini => _claveGemini;

  static Future<void> guardarClaveGemini(String clave) async {
    _claveGemini = clave.trim();
    await _llavero.write(key: 'clave_gemini', value: _claveGemini);
  }

  // -- la burbuja ----------------------------------------------------------

  /// Si la V flota encima de las demas aplicaciones.
  static bool get burbujaEncendida => _prefs.getBool('burbuja') ?? true;
  static Future<void> setBurbuja(bool valor) => _prefs.setBool('burbuja', valor);

  /// Lo grande que se ve la V flotando. Pequena para no molestar.
  static double get tamanoBurbuja => _prefs.getDouble('tamano_burbuja') ?? 64;
  static Future<void> setTamanoBurbuja(double valor) =>
      _prefs.setDouble('tamano_burbuja', valor);

  /// Que tan transparente esta cuando no la usas.
  static double get opacidadEnReposo => _prefs.getDouble('opacidad') ?? 0.55;
  static Future<void> setOpacidadEnReposo(double valor) =>
      _prefs.setDouble('opacidad', valor);

  // -- la rutina de la manana ----------------------------------------------

  static bool get rutinaEncendida => _prefs.getBool('rutina') ?? true;
  static Future<void> setRutina(bool valor) => _prefs.setBool('rutina', valor);

  /// La fecha del ultimo saludo, para dar uno al dia y no mas.
  static String get ultimoSaludo => _prefs.getString('ultimo_saludo') ?? '';
  static Future<void> setUltimoSaludo(String dia) =>
      _prefs.setString('ultimo_saludo', dia);

  /// Ciudad para el clima. Vacia significa "usa donde estoy".
  static String get ciudad => _prefs.getString('ciudad') ?? '';
  static Future<void> setCiudad(String valor) => _prefs.setString('ciudad', valor);

  // -- el modo seguridad ---------------------------------------------------

  static bool get seguridadEncendida => _prefs.getBool('seguridad') ?? false;
  static Future<void> setSeguridad(bool valor) =>
      _prefs.setBool('seguridad', valor);

  /// Que el telefono grite si lo mueven mientras esta vigilando.
  static bool get alarmaPorMovimiento => _prefs.getBool('alarma_movimiento') ?? true;
  static Future<void> setAlarmaPorMovimiento(bool valor) =>
      _prefs.setBool('alarma_movimiento', valor);

  // -- la voz --------------------------------------------------------------

  /// Si VALEN contesta hablando o solo escribe.
  static bool get vozEncendida => _prefs.getBool('voz') ?? true;
  static Future<void> setVoz(bool valor) => _prefs.setBool('voz', valor);
}
