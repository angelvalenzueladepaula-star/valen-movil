/// La V que flota encima de todo.
///
/// Es la forma de hablarle a VALEN en el telefono, y sustituye a la ventana
/// del escritorio. Vive por encima de las demas aplicaciones, pequena y medio
/// transparente para no estorbar, y reacciona a lo que le hagas:
///
///   un toque    -> te escucha; contesta ahi mismo, sin abrir nada
///   dos toques  -> abre la aplicacion entera
///   arrastrar   -> la mueves donde quieras
///   toque largo -> la manda a dormir hasta que la vuelvas a llamar
///
/// La respuesta corta sale en un globo junto a la V y se va sola. Para lo
/// largo (un ejercicio resuelto, por ejemplo) VALEN te dice que lo abras, y
/// ahi el doble toque te lleva a la conversacion completa.
///
/// COMO SE SOSTIENE ESTO EN ANDROID
///
/// Dibujar encima de otras aplicaciones necesita el permiso especial de
/// "mostrar sobre otras aplicaciones", que el usuario concede a mano una vez.
/// Y para que no la mate el sistema a los pocos minutos, detras hay un
/// servicio en primer plano con su aviso permanente. Las dos cosas son
/// requisitos de Android, no un capricho.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../nucleo/ajustes.dart';
import '../nucleo/cerebro.dart';
import '../nucleo/estados.dart';
import '../nucleo/voz.dart';
import 'v_animada.dart';

/// Punto de entrada de la burbuja. Android la arranca aparte de la aplicacion,
/// asi que necesita su propio `main`.
@pragma('vm:entry-point')
void puntoDeEntradaBurbuja() {
  runApp(const AppBurbuja());
}

class AppBurbuja extends StatelessWidget {
  const AppBurbuja({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(color: Colors.transparent, child: BurbujaValen()),
    );
  }
}

class BurbujaValen extends StatefulWidget {
  const BurbujaValen({super.key});

  @override
  State<BurbujaValen> createState() => _BurbujaValenState();
}

class _BurbujaValenState extends State<BurbujaValen> {
  EstadoValen _estado = EstadoValen.dormido;
  String _globo = '';
  Timer? _borrarGlobo;
  Timer? _esperandoSegundoToque;

  @override
  void initState() {
    super.initState();
    Voz.instancia.nivel.addListener(_alCambiarNivel);
    Ajustes.cargar();
  }

  @override
  void dispose() {
    Voz.instancia.nivel.removeListener(_alCambiarNivel);
    _borrarGlobo?.cancel();
    _esperandoSegundoToque?.cancel();
    super.dispose();
  }

  void _alCambiarNivel() {
    if (mounted) setState(() {});
  }

  void _pasarA(EstadoValen estado) {
    if (mounted) setState(() => _estado = estado);
  }

  void _decirEnElGlobo(String texto, {Duration cuanto = const Duration(seconds: 7)}) {
    _borrarGlobo?.cancel();
    if (!mounted) return;

    setState(() => _globo = texto);
    _borrarGlobo = Timer(cuanto, () {
      if (mounted) setState(() => _globo = '');
    });
  }

  // -- los gestos ----------------------------------------------------------

  /// Un toque puede ser el primero de dos. Se espera un poco antes de decidir:
  /// si llega otro dentro de ese rato, era doble y se abre la aplicacion.
  void _alTocar() {
    if (_esperandoSegundoToque?.isActive ?? false) {
      _esperandoSegundoToque!.cancel();
      _abrirLaApp();
      return;
    }

    _esperandoSegundoToque = Timer(const Duration(milliseconds: 280), _escuchar);
  }

  Future<void> _abrirLaApp() async {
    _decirEnElGlobo('Abriendo...', cuanto: const Duration(seconds: 2));
    await FlutterOverlayWindow.shareData({'accion': 'abrir_app'});
  }

  Future<void> _escuchar() async {
    if (_estado == EstadoValen.escuchando) {
      await Voz.instancia.parar();
      _pasarA(EstadoValen.dormido);
      return;
    }

    _pasarA(EstadoValen.escuchando);
    _decirEnElGlobo('Te escucho...', cuanto: const Duration(seconds: 14));

    final pregunta = await Voz.instancia.escuchar();

    if (pregunta.isEmpty) {
      _pasarA(EstadoValen.dormido);
      _decirEnElGlobo('No te oi bien.', cuanto: const Duration(seconds: 3));
      return;
    }

    _pasarA(EstadoValen.pensando);
    _decirEnElGlobo(pregunta, cuanto: const Duration(seconds: 20));

    final respuesta = await Cerebro.instancia.responder(pregunta);

    if (respuesta.fallo) {
      _pasarA(EstadoValen.error);
      _decirEnElGlobo(respuesta.texto);
      Timer(const Duration(seconds: 3), () => _pasarA(EstadoValen.dormido));
      return;
    }

    // Lo que no cabe en un globo se anuncia y se deja en la aplicacion.
    final largo = respuesta.texto.length > 220;
    _pasarA(EstadoValen.hablando);
    _decirEnElGlobo(
      largo ? '${respuesta.texto.substring(0, 200)}...\n\n(toca dos veces para leerlo entero)'
            : respuesta.texto,
      cuanto: Duration(seconds: largo ? 14 : 9),
    );

    // La conversacion se guarda para que al abrir la aplicacion este ahi.
    await FlutterOverlayWindow.shareData(jsonEncode({
      'accion': 'guardar_turno',
      'pregunta': pregunta,
      'respuesta': respuesta.texto,
    }));

    await Voz.instancia.hablar(respuesta.texto);
    _pasarA(EstadoValen.dormido);
  }

  Future<void> _alDejarPulsado() async {
    await Voz.instancia.callar();
    await Voz.instancia.parar();
    _pasarA(EstadoValen.dormido);
    _decirEnElGlobo('Hasta luego.', cuanto: const Duration(seconds: 2));
    await FlutterOverlayWindow.closeOverlay();
  }

  // -- lo que se ve --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lado = Ajustes.burbujaEncendida ? Ajustes.tamanoBurbuja : 64.0;
    final dormida = _estado == EstadoValen.dormido;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (_globo.isNotEmpty)
          Positioned(
            bottom: lado + 6,
            child: _Globo(texto: _globo),
          ),
        GestureDetector(
          onTap: _alTocar,
          onLongPress: _alDejarPulsado,
          child: AnimatedOpacity(
            // Dormida se aparta del camino; despierta se ve entera.
            opacity: dormida ? Ajustes.opacidadEnReposo : 1.0,
            duration: const Duration(milliseconds: 400),
            child: VAnimada(
              estado: _estado,
              lado: lado,
              nivelVoz: Voz.instancia.nivel.value,
            ),
          ),
        ),
      ],
    );
  }
}

/// El globo de texto que sale junto a la V.
class _Globo extends StatelessWidget {
  const _Globo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xEE04121A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x555FE3FF)),
        boxShadow: const [
          BoxShadow(color: Color(0x335FE3FF), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Color(0xFFDDF6FF),
          fontSize: 13,
          height: 1.35,
        ),
      ),
    );
  }
}
