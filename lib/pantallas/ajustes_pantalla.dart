/// Ajustes: la clave del cerebro, la burbuja, la voz y los modos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../nucleo/ajustes.dart';
import '../nucleo/memoria.dart';
import '../nucleo/sesion.dart';
import '../servicios/burbuja_servicio.dart';

class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  final _clave = TextEditingController();
  bool _mostrarClave = false;

  @override
  void initState() {
    super.initState();
    _clave.text = Ajustes.claveGemini;
  }

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Titulo('El cerebro'),
          TextField(
            controller: _clave,
            obscureText: !_mostrarClave,
            decoration: InputDecoration(
              labelText: 'Clave de Gemini',
              helperText: 'Se saca gratis en aistudio.google.com/apikey',
              helperMaxLines: 2,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_mostrarClave ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _mostrarClave = !_mostrarClave),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              await Ajustes.guardarClaveGemini(_clave.text);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clave guardada en el llavero del telefono.')),
              );
            },
            child: const Text('Guardar clave'),
          ),

          const _Titulo('La V flotante'),
          SwitchListTile(
            title: const Text('Mostrar la V encima de todo'),
            subtitle: const Text('Un toque para hablarle, dos para abrir esto'),
            value: Ajustes.burbujaEncendida,
            onChanged: (valor) async {
              await Ajustes.setBurbuja(valor);
              if (valor) {
                await BurbujaServicio.encender();
              } else {
                await FlutterOverlayWindow.closeOverlay();
              }
              setState(() {});
            },
          ),
          ListTile(
            title: const Text('Tamano'),
            subtitle: Slider(
              value: Ajustes.tamanoBurbuja,
              min: 48,
              max: 110,
              divisions: 31,
              label: Ajustes.tamanoBurbuja.round().toString(),
              onChanged: (v) async {
                await Ajustes.setTamanoBurbuja(v);
                setState(() {});
              },
            ),
          ),
          ListTile(
            title: const Text('Transparencia en reposo'),
            subtitle: Slider(
              value: Ajustes.opacidadEnReposo,
              min: 0.2,
              max: 1.0,
              divisions: 16,
              onChanged: (v) async {
                await Ajustes.setOpacidadEnReposo(v);
                setState(() {});
              },
            ),
          ),

          const _Titulo('Voz y rutinas'),
          SwitchListTile(
            title: const Text('Que conteste hablando'),
            value: Ajustes.vozEncendida,
            onChanged: (v) async {
              await Ajustes.setVoz(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Saludo de la manana'),
            subtitle: const Text('La primera vez de cada dia te resume como viene'),
            value: Ajustes.rutinaEncendida,
            onChanged: (v) async {
              await Ajustes.setRutina(v);
              setState(() {});
            },
          ),

          const _Titulo('Tu cuenta'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(Sesion.nombre),
            subtitle: Text(Sesion.usuario?.email ?? 'sin cuenta'),
          ),
          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: const Text('Lo que VALEN sabe de ti'),
            subtitle: Text('${Memoria.instancia.hechos.length} cosas anotadas'),
            onTap: () => _verMemoria(context),
          ),
          if (Sesion.haEntrado)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Cerrar sesion'),
              onTap: () async {
                await Sesion.salir();
                Memoria.instancia.reiniciar();
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  void _verMemoria(BuildContext context) {
    final hechos = Memoria.instancia.hechos;

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Lo que VALEN ha aprendido de ti',
              style: TextStyle(fontSize: 16, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (hechos.isEmpty)
            const Text('Todavia nada. Se ira llenando segun le cuentes cosas.',
                style: TextStyle(color: Colors.white54)),
          for (final hecho in hechos)
            ListTile(
              dense: true,
              title: Text(hecho.clave),
              subtitle: Text(hecho.valor),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () async {
                  await Memoria.instancia.olvidar(hecho.clave);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 2,
          color: Color(0xFF5FE3FF),
        ),
      ),
    );
  }
}
