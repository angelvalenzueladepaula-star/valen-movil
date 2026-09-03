/// VALEN para Android.
///
/// La aplicacion tiene dos entradas, y eso es lo primero que hay que entender
/// de este archivo:
///
/// - [main] es la aplicacion normal, la que se ve al abrir el icono.
/// - [puntoDeEntradaBurbuja] (en burbuja/burbuja.dart) es la V flotante, que
///   Android arranca en un motor de Flutter aparte.
///
/// Son dos procesos distintos que no comparten memoria viva. Se hablan por
/// mensajes, que es lo que hace `FlutterOverlayWindow.shareData`. Por eso la
/// burbuja no puede simplemente llamar a una funcion de aqui.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'nucleo/ajustes.dart';
import 'nucleo/estados.dart';
import 'nucleo/memoria.dart';
import 'nucleo/sesion.dart';
import 'pantallas/chat.dart';
import 'pantallas/entrar.dart';
import 'servicios/burbuja_servicio.dart';

// La burbuja necesita su propio punto de entrada visible desde Android.
export 'burbuja/burbuja.dart' show puntoDeEntradaBurbuja;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Ajustes.cargar();
  await Sesion.preparar();
  BurbujaServicio.prepararServicio();

  runApp(const AppValen());
}

class AppValen extends StatelessWidget {
  const AppValen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VALEN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF04121A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1AA8C9),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF061A24)),
      ),
      home: const Puerta(),
    );
  }
}

/// Decide que se ve al abrir: la conversacion o la pantalla de entrar.
class Puerta extends StatefulWidget {
  const Puerta({super.key});

  @override
  State<Puerta> createState() => _PuertaState();
}

class _PuertaState extends State<Puerta> {
  bool _dentro = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _arrancar();
    _escucharALaBurbuja();
  }

  Future<void> _arrancar() async {
    // Sin servidor de cuentas, o con sesion ya abierta, se entra directo.
    if (!Sesion.configurado || Sesion.haEntrado) {
      await Memoria.instancia.cargar();
      _dentro = true;
    }

    if (mounted) setState(() => _cargando = false);

    await BurbujaServicio.encenderSiTocaAlArrancar();
  }

  /// La burbuja manda avisos: que se abra la aplicacion, o un turno de
  /// conversacion que hubo mientras la aplicacion estaba cerrada.
  void _escucharALaBurbuja() {
    FlutterOverlayWindow.overlayListener.listen((mensaje) {
      if (!mounted) return;

      Map<String, dynamic>? datos;
      if (mensaje is Map) {
        datos = Map<String, dynamic>.from(mensaje);
      } else if (mensaje is String) {
        try {
          datos = jsonDecode(mensaje) as Map<String, dynamic>;
        } catch (_) {
          return;
        }
      }

      if (datos?['accion'] == 'abrir_app') {
        setState(() => _dentro = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_dentro) {
      return PantallaEntrar(alEntrar: () => setState(() => _dentro = true));
    }

    return const PantallaChat();
  }
}

/// Se exporta para que otras partes puedan pintar el estado sin importar todo.
EstadoValen get estadoInicial => EstadoValen.dormido;
