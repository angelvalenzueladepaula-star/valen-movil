/// La lista de conversaciones guardadas.
///
/// Es el cajon lateral, y es lo que convierte a VALEN en algo con lo que se
/// puede trabajar de verdad: la tarea del martes sigue ahi el jueves, con las
/// fotos y todo.
///
/// El buscador mira dentro de lo que se dijo, no solo en los titulos, porque
/// asi es como uno recuerda las cosas: no por el titulo que le puso, sino por
/// "aquella vez que le pregunte por las derivadas".
library;

import 'package:flutter/material.dart';

import '../nucleo/historial.dart';

class ListaConversaciones extends StatefulWidget {
  const ListaConversaciones({
    super.key,
    required this.actual,
    required this.alElegir,
    required this.alBorrarLaActual,
  });

  final int? actual;
  final void Function(Conversacion) alElegir;

  /// Se avisa cuando se borra la conversacion que estaba abierta, para que la
  /// pantalla de detras no se quede mirando algo que ya no existe.
  final VoidCallback alBorrarLaActual;

  @override
  State<ListaConversaciones> createState() => _ListaConversacionesState();
}

class _ListaConversacionesState extends State<ListaConversaciones> {
  final _buscador = TextEditingController();
  List<Conversacion> _lista = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    final lista =
        await Historial.instancia.conversaciones(buscar: _buscador.text);
    if (mounted) {
      setState(() {
        _lista = lista;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF061A24),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text('VALEN',
                      style: TextStyle(fontSize: 17, letterSpacing: 5)),
                  const Spacer(),
                  Text('${_lista.length}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _buscador,
                onChanged: (_) => _recargar(),
                decoration: InputDecoration(
                  hintText: 'Buscar en lo que hablamos',
                  hintStyle: const TextStyle(fontSize: 12),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _buscador.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _buscador.clear();
                            _recargar();
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _lista.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Nada guardado todavia.',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _lista.length,
                          itemBuilder: (_, i) => _Fila(
                            conversacion: _lista[i],
                            esLaAbierta: _lista[i].id == widget.actual,
                            alTocar: () => widget.alElegir(_lista[i]),
                            alRenombrar: () => _renombrar(_lista[i]),
                            alBorrar: () => _borrar(_lista[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renombrar(Conversacion cual) async {
    final campo = TextEditingController(text: cual.titulo);

    final nuevo = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Como se llama'),
        content: TextField(controller: campo, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Dejarlo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(campo.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (nuevo != null && nuevo.trim().isNotEmpty) {
      await Historial.instancia.renombrar(cual.id!, nuevo);
      await _recargar();
    }
  }

  Future<void> _borrar(Conversacion cual) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Borrar esta conversacion'),
        content: const Text(
          'Se borra entera, con sus fotos. Esto no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (seguro != true) return;

    final eraLaAbierta = cual.id == widget.actual;
    await Historial.instancia.borrar(cual.id!);
    await _recargar();

    if (eraLaAbierta) widget.alBorrarLaActual();
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.conversacion,
    required this.esLaAbierta,
    required this.alTocar,
    required this.alRenombrar,
    required this.alBorrar,
  });

  final Conversacion conversacion;
  final bool esLaAbierta;
  final VoidCallback alTocar;
  final VoidCallback alRenombrar;
  final VoidCallback alBorrar;

  /// La fecha como la diria una persona: hoy, ayer, o el dia.
  String get _cuando {
    final ahora = DateTime.now();
    final dia = conversacion.tocada;
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final suyo = DateTime(dia.year, dia.month, dia.day);
    final diferencia = hoy.difference(suyo).inDays;

    if (diferencia == 0) {
      return '${dia.hour.toString().padLeft(2, '0')}:'
          '${dia.minute.toString().padLeft(2, '0')}';
    }
    if (diferencia == 1) return 'ayer';
    if (diferencia < 7) return 'hace $diferencia dias';

    return '${dia.day}/${dia.month}';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: esLaAbierta,
      selectedTileColor: const Color(0x225FE3FF),
      title: Text(
        conversacion.titulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(_cuando,
          style: const TextStyle(fontSize: 10, color: Colors.white38)),
      onTap: alTocar,
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (que) => que == 'renombrar' ? alRenombrar() : alBorrar(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'renombrar', child: Text('Cambiar el nombre')),
          PopupMenuItem(value: 'borrar', child: Text('Borrar')),
        ],
      ),
    );
  }
}
