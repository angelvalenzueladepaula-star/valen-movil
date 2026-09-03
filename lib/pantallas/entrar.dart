/// Entrar o crear cuenta.
///
/// Aqui es donde VALEN deja de ser de una sola persona. Cada quien tiene su
/// cuenta, y lo que VALEN aprende de uno no lo sabe de los demas.
///
/// Se puede saltar: sin cuenta VALEN funciona igual, pero lo que aprenda se
/// queda solo en este telefono y se pierde si lo cambias.
library;

import 'package:flutter/material.dart';

import '../burbuja/v_animada.dart';
import '../nucleo/estados.dart';
import '../nucleo/memoria.dart';
import '../nucleo/sesion.dart';

class PantallaEntrar extends StatefulWidget {
  const PantallaEntrar({super.key, required this.alEntrar});

  final VoidCallback alEntrar;

  @override
  State<PantallaEntrar> createState() => _PantallaEntrarState();
}

class _PantallaEntrarState extends State<PantallaEntrar> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _nombre = TextEditingController();

  bool _registrando = false;
  bool _trabajando = false;
  String _error = '';

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _adelante() async {
    setState(() {
      _trabajando = true;
      _error = '';
    });

    final fallo = _registrando
        ? await Sesion.registrarse(_correo.text, _contrasena.text, _nombre.text)
        : await Sesion.entrar(_correo.text, _contrasena.text);

    if (!mounted) return;

    if (fallo != null) {
      setState(() {
        _trabajando = false;
        _error = fallo;
      });
      return;
    }

    await Memoria.instancia.cargar();
    if (mounted) widget.alEntrar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VAnimada(estado: EstadoValen.dormido, lado: 130),
                const SizedBox(height: 8),
                const Text('VALEN', style: TextStyle(fontSize: 26, letterSpacing: 8)),
                const SizedBox(height: 6),
                Text(
                  _registrando
                      ? 'Crea tu cuenta y VALEN empezara a conocerte'
                      : 'Entra y VALEN recordara lo que sabe de ti',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 28),

                if (!Sesion.configurado) ...[
                  const Card(
                    color: Color(0xFF2A1F00),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Todavia no hay servidor de cuentas configurado. Puedes '
                        'usar VALEN sin cuenta: lo que aprenda se quedara en '
                        'este telefono.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_registrando)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _nombre,
                      decoration: const InputDecoration(
                        labelText: 'Como quieres que te llame',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                TextField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contrasena,
                  obscureText: true,
                  onSubmitted: (_) => _adelante(),
                  decoration: const InputDecoration(
                    labelText: 'Contrasena',
                    border: OutlineInputBorder(),
                  ),
                ),

                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_trabajando || !Sesion.configurado) ? null : _adelante,
                    child: _trabajando
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_registrando ? 'Crear cuenta' : 'Entrar'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _registrando = !_registrando;
                    _error = '';
                  }),
                  child: Text(_registrando
                      ? 'Ya tengo cuenta'
                      : 'No tengo cuenta, quiero crear una'),
                ),
                TextButton(
                  onPressed: widget.alEntrar,
                  child: const Text(
                    'Entrar sin cuenta',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
