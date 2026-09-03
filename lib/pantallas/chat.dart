/// La aplicacion entera: hablar con VALEN y mandarle ejercicios.
///
/// Esta es la pantalla a la que se llega con el doble toque en la V, y es
/// donde vive lo que el telefono hace mejor que el escritorio: **mandarle
/// fotos**. Un cuestionario, una hoja de ejercicios, la pizarra de clase, y
/// que lo resuelva.
///
/// Se pueden mandar varias imagenes a la vez a proposito: un examen tiene
/// varias hojas, y separarlas en mensajes distintos hace que VALEN pierda el
/// hilo entre unas y otras.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../burbuja/v_animada.dart';
import '../nucleo/cerebro.dart';
import '../nucleo/estados.dart';
import '../nucleo/sesion.dart';
import '../nucleo/voz.dart';
import 'ajustes_pantalla.dart';

class Turno {
  Turno({required this.mio, required this.texto, this.imagenes = const []});

  final bool mio;
  final String texto;
  final List<Uint8List> imagenes;
}

class PantallaChat extends StatefulWidget {
  const PantallaChat({super.key});

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  final _escrito = TextEditingController();
  final _rollo = ScrollController();
  final _turnos = <Turno>[];
  final _adjuntas = <Uint8List>[];

  EstadoValen _estado = EstadoValen.dormido;

  @override
  void initState() {
    super.initState();
    Voz.instancia.nivel.addListener(_refrescar);
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

  Future<void> _adjuntar({required bool conCamara}) async {
    final selector = ImagePicker();

    if (conCamara) {
      final foto = await selector.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (foto != null) {
        final datos = await foto.readAsBytes();
        setState(() => _adjuntas.add(datos));
      }
      return;
    }

    // Varias de golpe: un examen suele tener mas de una hoja.
    final fotos = await selector.pickMultiImage(imageQuality: 82, maxWidth: 1600);
    for (final foto in fotos) {
      _adjuntas.add(await foto.readAsBytes());
    }
    if (mounted) setState(() {});
  }

  Future<void> _enviar() async {
    final texto = _escrito.text.trim();
    if (texto.isEmpty && _adjuntas.isEmpty) return;

    final imagenes = List<Uint8List>.from(_adjuntas);
    final pregunta = texto.isEmpty
        // Con solo fotos y sin texto, lo que se quiere es obvio.
        ? 'Resuelve lo que hay en estas imagenes, explicando lo justo.'
        : texto;

    setState(() {
      _turnos.add(Turno(mio: true, texto: pregunta, imagenes: imagenes));
      _escrito.clear();
      _adjuntas.clear();
      _estado = EstadoValen.pensando;
    });
    _bajarDelTodo();

    final respuesta = await Cerebro.instancia.responder(pregunta, imagenes: imagenes);

    if (!mounted) return;
    setState(() {
      _turnos.add(Turno(mio: false, texto: respuesta.texto));
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

  void _bajarDelTodo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_rollo.hasClients) {
        _rollo.animateTo(
          _rollo.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            VAnimada(
              estado: _estado,
              lado: 38,
              nivelVoz: Voz.instancia.nivel.value,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('VALEN', style: TextStyle(letterSpacing: 3, fontSize: 15)),
                Text(
                  _estado.nombre,
                  style: TextStyle(fontSize: 10, color: _estado.color),
                ),
              ],
            ),
          ],
        ),
        actions: [
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
            child: _turnos.isEmpty
                ? const _Bienvenida()
                : ListView.builder(
                    controller: _rollo,
                    padding: const EdgeInsets.all(12),
                    itemCount: _turnos.length,
                    itemBuilder: (_, i) => _Burbuja(turno: _turnos[i]),
                  ),
          ),
          if (_adjuntas.isNotEmpty) _TiraDeFotos(
            fotos: _adjuntas,
            alQuitar: (i) => setState(() => _adjuntas.removeAt(i)),
          ),
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
              'Preguntame lo que sea, o mandame una foto de tus ejercicios y '
              'te los resuelvo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.5, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.turno});

  final Turno turno;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: turno.mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
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
            if (turno.imagenes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final imagen in turno.imagenes)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(imagen, width: 92, height: 92, fit: BoxFit.cover),
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
}

class _TiraDeFotos extends StatelessWidget {
  const _TiraDeFotos({required this.fotos, required this.alQuitar});

  final List<Uint8List> fotos;
  final void Function(int) alQuitar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
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
                child: Image.memory(fotos[i], width: 62, height: 62, fit: BoxFit.cover),
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
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.photo_camera_outlined), onPressed: alHacerFoto),
            IconButton(icon: const Icon(Icons.image_outlined), onPressed: alElegirFotos),
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
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
