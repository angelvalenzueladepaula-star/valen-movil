/// Quien esta usando VALEN.
///
/// En el escritorio VALEN era de una sola persona: reconocia la voz de Sebas y
/// punto. En el telefono eso no sirve, porque la aplicacion la puede instalar
/// cualquiera. Asi que aqui hay cuenta de usuario de verdad, y **la memoria de
/// cada uno es suya**: lo que VALEN aprende de ti no lo sabe de nadie mas.
///
/// POR QUE SUPABASE
///
/// Hace falta base de datos y registro de usuarios, gratis y sin tarjeta.
/// Supabase da las dos cosas sobre PostgreSQL, que es lo mismo que ya usa la
/// version de escritorio, asi que las tablas se parecen y se entienden igual.
///
/// LA CLAVE QUE SI PUEDE IR EN EL CODIGO
///
/// La clave "anon" de Supabase esta pensada para ir dentro de la aplicacion:
/// no da acceso a nada por si sola. Quien protege los datos es la regla de
/// seguridad por fila del servidor, que dice que cada usuario solo ve lo suyo.
/// Sin esa regla, esta clave si seria un agujero, asi que viene explicada en
/// el README y hay que ponerla antes de usar la aplicacion en serio.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class Sesion {
  /// Se rellenan con los datos del proyecto de Supabase. Ver el README.
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String claveAnonima = String.fromEnvironment('SUPABASE_ANON');

  static bool get configurado => url.isNotEmpty && claveAnonima.isNotEmpty;

  /// Se llama al arrancar la aplicacion.
  static Future<void> preparar() async {
    if (!configurado) return;

    await Supabase.initialize(
      url: url,
      publishableKey: claveAnonima,
      authOptions: const FlutterAuthClientOptions(
        // La sesion se guarda, para no pedir la contrasena cada vez que se
        // abre. En un asistente que vive en segundo plano eso es esencial.
        autoRefreshToken: true,
      ),
    );
  }

  static SupabaseClient get _cliente => Supabase.instance.client;

  static User? get usuario => configurado ? _cliente.auth.currentUser : null;
  static bool get haEntrado => usuario != null;

  /// El nombre con el que VALEN se dirige a esta persona.
  static String get nombre {
    final datos = usuario?.userMetadata ?? {};
    final puesto = (datos['nombre'] as String?)?.trim();
    if (puesto != null && puesto.isNotEmpty) return puesto;

    final correo = usuario?.email ?? '';
    return correo.isEmpty ? 'tu' : correo.split('@').first;
  }

  static Stream<AuthState> get cambios => _cliente.auth.onAuthStateChange;

  // -- entrar y salir ------------------------------------------------------

  static Future<String?> registrarse(
    String correo,
    String contrasena,
    String nombre,
  ) async {
    try {
      await _cliente.auth.signUp(
        email: correo.trim(),
        password: contrasena,
        data: {'nombre': nombre.trim()},
      );
      return null;
    } on AuthException catch (error) {
      return _enCristiano(error.message);
    } catch (error) {
      return 'No pude crear la cuenta: $error';
    }
  }

  static Future<String?> entrar(String correo, String contrasena) async {
    try {
      await _cliente.auth.signInWithPassword(
        email: correo.trim(),
        password: contrasena,
      );
      return null;
    } on AuthException catch (error) {
      return _enCristiano(error.message);
    } catch (error) {
      return 'No pude entrar: $error';
    }
  }

  static Future<void> salir() async {
    if (configurado) await _cliente.auth.signOut();
  }

  /// Los mensajes de Supabase vienen en ingles y de tecnico. Aqui se dicen
  /// como se los dirias a alguien.
  static String _enCristiano(String mensaje) {
    final texto = mensaje.toLowerCase();

    if (texto.contains('invalid login')) {
      return 'Ese correo o esa contrasena no son.';
    }
    if (texto.contains('already registered')) {
      return 'Ese correo ya tiene cuenta. Entra en vez de registrarte.';
    }
    if (texto.contains('password') && texto.contains('6')) {
      return 'La contrasena necesita al menos seis caracteres.';
    }
    if (texto.contains('email') && texto.contains('confirm')) {
      return 'Falta confirmar el correo. Mira tu bandeja de entrada.';
    }

    return mensaje;
  }
}
