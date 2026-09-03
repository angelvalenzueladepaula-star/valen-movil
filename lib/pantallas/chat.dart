/// La aplicacion entera: hablar con VALEN y mandarle tareas.
///
/// Es la pantalla a la que se llega con el doble toque en la V, y funciona
/// como cualquier asistente al que estas acostumbrado: **todo queda guardado**.
/// Cada conversacion tiene su titulo y sigue ahi cuando vuelvas.
///
/// Y es donde vive lo que el telefono hace mejor que el escritorio: mandarle
/// **fotos de la tarea**. Varias a la vez a proposito, porque un examen tiene
/// varias hojas y separarlas en mensajes distintos hace que VALEN pierda el
/// hilo entre unas y otras.
///
/// Al adjuntar fotos salen cuatro botones, que son las cuatro cosas que de
/// verdad se piden al estudiar: resolverlo, entenderlo, copiarlo rapido, o
/// saber si lo que ya escribiste esta bien.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../burbuja/v_animada.dart';
import '../nucleo/cerebro.dart';
import '../nucleo/estados.dart';
import '../nucleo/historial.dart';
import '../nucleo/sesion.dart';
import '../nucleo/voz.dart';
import 'ajustes_pantalla.dart';
import 'conversaciones.dart';

class PantallaChat extends StatefulWidget {
  const PantallaChat({super.key});

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  final _escrito = TextEditingController();
  final _rollo = ScrollController();
  final _adjuntas = <Uint8List>[];

  Conversacion? _conversacion;
  List<Turno> _turnos = [];
  EstadoValen _estado = EstadoValen.dormido;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    Voz.instancia.nivel.addListener(_refrescar);
    _abrirUltimaOCrear();
  }

  @override
  void dispose() {
    Voz.instancia.nivel.removeListener(_refrescar);
    _escrito.dispose();
    _rollo.dispose();
    super.dispose();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  /// Al abrir, se retoma la ultima conversacion. Empezar siempre de cero
  /// obligaria a buscar en la lista lo que estabas haciendo hace un minuto.
  Future<void> _abrirUltimaOCrear() async {
    try {
      final todas = await Historial.instancia.conversaciones();
      final cual =
          todas.isNotEmpty ? todas.first : await Historial.instancia.nueva();
      await _abrir(cual);
    } catch (error) {
      // Sin historial VALEN sigue sirviendo: se conversa igual, solo que no
      // queda guardado. Peor seria una pantalla en blanco.
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pude abrir el historial: $error')),
      );
    }
  }

  Future<void> _abrir(Conversacion cual) async {
    final turnos = await Historial.instancia.turnos(cual.id!);
    if (!mounted) return;

    setState(() {
      _conversacion = cual;
      _turnos = turnos;
      _cargando = false;
    });
    _bajarDelTodo(deGolpe: true);
  }

  Future<void> _empezarNueva() async {
    final cual = await Historial.instancia.nueva();
    await _abrir(cual);
  }

  // -- fotos ---------------------------------------------------------------

  Future<void> _adjuntar({required bool conCamara}) async {
    final selector = ImagePicker();

    try {
      if (conCamara) {
        final foto = await selector.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1800,
        );
        if (foto != null) _adjuntas.add(await foto.readAsBytes());
      } else {
        // Varias de golpe: un examen suele tener mas de una hoja.
        final fotos =
            await selector.pickMultiImage(imageQuality: 85, maxWidth: 1800);
        for (final foto in fotos) {
          _adjuntas.add(await foto.readAsBytes());
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No pude coger la foto: $error')),
        );
      }
    }

    if (mounted) setState(() {});
  }

  // -- mandar --------------------------------------------------------------

  Future<void> _enviar({ModoTarea modo = ModoTarea.normal}) async {
    final escrito = _escrito.text.trim();
    if (escrito.isEmpty && _adjuntas.isEmpty) return;
    if (_conversacion == null) return;
    if (_estado == EstadoValen.pensando) return; // ya hay una en marcha

    final imagenes = List<Uint8List>.from(_adjuntas);
    final pregunta = escrito.isNotEmpty
        ? escrito
        // Con solo fotos y sin texto, lo que se quiere es evidente.
        : (modo == ModoTarea.normal
            ? 'Mira estas imagenes y resuelve lo que haya en ellas.'
            : modo.instruccion);

    // El hilo que se le manda al cerebro es el de ANTES de este mensaje.
    final anteriores = List<Turno>.from(_turnos);

    final mio = await Historial.instancia.anotar(
      _conversacion!.id!,
      mio: true,
      texto: pregunta,
      imagenes: imagenes,
    );

    setState(() {
      _turnos.add(mio);
      _escrito.clear();
      _adjuntas.clear();
      _estado = EstadoValen.pensando;
    });
    _bajarDelTodo();

    // La primera pregunta le pone nombre a la conversacion.
    if (anteriores.isEmpty) {
      final titulo = await Historial.instancia.titularSegunLoPrimero(
        _conversacion!.id!,
        escrito,
        teniaFotos: imagenes.isNotEmpty,
      );
      if (mounted) setState(() => _conversacion!.titulo = titulo);
    }

    final respuesta = await Cerebro.instancia.responder(
      pregunta,
      imagenes: imagenes,
      anteriores: anteriores,
      modo: modo,
    );

    final suyo = await Historial.instancia.anotar(
      _conversacion!.id!,
      mio: false,
      texto: respuesta.texto,
    );

    if (!mounted) return;
    setState(() {
      _turnos.add(suyo);
      _estado = respuesta.fallo ? EstadoValen.error : EstadoValen.hablando;
    });
    _bajarDelTodo();

    await Voz.instancia.hablar(respuesta.texto);
    if (mounted) setState(() => _estado = EstadoValen.dormido);
  }

  Future<void> _dictar() async {
    setState(() => _estado = EstadoValen.escuchando);
    final dicho = await Voz.instancia.escuchar();

    if (!mounted) return;
    setState(() {
      _estado = EstadoValen.dormido;
      if (dicho.isNotEmpty) _escrito.text = dicho;
    });

    if (dicho.isNotEmpty) _enviar();
  }

  void _bajarDelTodo({bool deGolpe = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rollo.hasClients) return;

      final fondo = _rollo.position.maxScrollExtent;
      if (deGolpe) {
        _rollo.jumpTo(fondo);
      } else {
        _rollo.animateTo(
          fondo,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // -- lo que se ve --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: ListaConversaciones(
        actual: _conversacion?.id,
        alElegir: (cual) {
          Navigator.of(context).pop();
          _abrir(cual);
        },
        alBorrarLaActual: _abrirUltimaOCrear,
      ),
      appBar: AppBar(
        titleSpacing: 0,
        // El boton de siempre trae su texto de ayuda en ingles; aqui se pone
        // el propio para que no se escape una palabra sin traducir.
        leading: Builder(
          builder: (contexto) => IconButton(
            tooltip: 'Tus conversaciones',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(contexto).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            VAnimada(
              estado: _estado,
              lado: 36,
              nivelVoz: Voz.instancia.nivel.value,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _conversacion?.titulo ?? 'VALEN',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    _estado.nombre,
                    style: TextStyle(fontSize: 10, color: _estado.color),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Conversacion nueva',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _empezarNueva,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PantallaAjustes()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _turnos.isEmpty
                    ? const _Bienvenida()
                    : ListView.builder(
                        controller: _rollo,
                        padding: const EdgeInsets.all(12),
                        itemCount: _turnos.length + 1,
                        itemBuilder: (_, i) => i == _turnos.length
                            ? _Pensando(visible: _estado == EstadoValen.pensando)
                            : _BurbujaTurno(turno: _turnos[i]),
                      ),
          ),
          if (_adjuntas.isNotEmpty) ...[
            _TiraDeFotos(
              fotos: _adjuntas,
              alQuitar: (i) => setState(() => _adjuntas.removeAt(i)),
            ),
            _BotonesDeTarea(alElegir: (modo) => _enviar(modo: modo)),
          ],
          _BarraDeEscribir(
            controlador: _escrito,
            alEnviar: _enviar,
            alDictar: _dictar,
            alHacerFoto: () => _adjuntar(conCamara: true),
            alElegirFotos: () => _adjuntar(conCamara: false),
            escuchando: _estado == EstadoValen.escuchando,
          ),
        ],
      ),
    );
  }
}

/// Los cuatro botones que salen al adjuntar fotos.
class _BotonesDeTarea extends StatelessWidget {
  const _BotonesDeTarea({required this.alElegir});

  final void Function(ModoTarea) alElegir;

  @override
  Widget build(BuildContext context) {
    const modos = [
      ModoTarea.resolverTodo,
      ModoTarea.pasoAPaso,
      ModoTarea.soloRespuestas,
      ModoTarea.revisarLoMio,
    ];

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          for (final modo in modos)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 6),
              child: ActionChip(
                label: Text(modo.etiqueta, style: const TextStyle(fontSize: 12)),
                onPressed: () => alElegir(modo),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pensando extends StatelessWidget {
  const _Pensando({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(height: 8);

    return const Padding(
      padding: EdgeInsets.only(left: 4, top: 4, bottom: 12),
      child: Row(
        children: [
          VAnimada(estado: EstadoValen.pensando, lado: 42),
          SizedBox(width: 4),
          Text('leyendo...',
              style: TextStyle(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  const _Bienvenida();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VAnimada(estado: EstadoValen.dormido, lado: 130),
            const SizedBox(height: 20),
            Text(
              'Hola, ${Sesion.nombre}',
              style: const TextStyle(fontSize: 20, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            const Text(
              'Preguntame lo que sea, o mandame las fotos de tu tarea y te la '
              'resuelvo pregunta por pregunta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.5, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _BurbujaTurno extends StatelessWidget {
  const _BurbujaTurno({required this.turno});

  final Turno turno;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: turno.mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        decoration: BoxDecoration(
          color: turno.mio ? const Color(0xFF10333F) : const Color(0xFF0A2029),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: turno.mio ? const Color(0x335FE3FF) : const Color(0x22FFFFFF),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (turno.tieneImagenes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final ruta in turno.rutasImagenes)
                      GestureDetector(
                        onTap: () => _verGrande(context, ruta),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(ruta),
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 96,
                              height: 96,
                              child: Icon(Icons.broken_image_outlined, size: 20),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            SelectableText(
              turno.texto,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  void _verGrande(BuildContext context, String ruta) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(File(ruta)),
        ),
      ),
    );
  }
}

class _TiraDeFotos extends StatelessWidget {
  const _TiraDeFotos({required this.fotos, required this.alQuitar});

  final List<Uint8List> fotos;
  final void Function(int) alQuitar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: fotos.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(fotos[i],
                    width: 62, height: 62, fit: BoxFit.cover),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: () => alQuitar(i),
                  child: const CircleAvatar(
                    radius: 9,
                    backgroundColor: Colors.black87,
                    child: Icon(Icons.close, size: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarraDeEscribir extends StatelessWidget {
  const _BarraDeEscribir({
    required this.controlador,
    required this.alEnviar,
    required this.alDictar,
    required this.alHacerFoto,
    required this.alElegirFotos,
    required this.escuchando,
  });

  final TextEditingController controlador;
  final VoidCallback alEnviar;
  final VoidCallback alDictar;
  final VoidCallback alHacerFoto;
  final VoidCallback alElegirFotos;
  final bool escuchando;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Hacer una foto',
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: alHacerFoto,
            ),
            IconButton(
              tooltip: 'Elegir fotos',
              icon: const Icon(Icons.image_outlined),
              onPressed: alElegirFotos,
            ),
            Expanded(
              child: TextField(
                controller: controlador,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => alEnviar(),
                decoration: const InputDecoration(
                  hintText: 'Preguntale a VALEN...',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            IconButton(
              icon: Icon(escuchando ? Icons.mic : Icons.mic_none),
              color: escuchando ? const Color(0xFF5FE3FF) : null,
              onPressed: alDictar,
            ),
            IconButton(icon: const Icon(Icons.send), onPressed: alEnviar),
          ],
        ),
      ),
    );
  }
}
