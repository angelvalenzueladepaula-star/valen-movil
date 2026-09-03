/// Los oidos y la boca de VALEN en el telefono.
///
/// Aqui hay una diferencia importante con el escritorio: **el telefono no
/// escucha todo el rato**. En el ordenador el microfono esta siempre abierto
/// esperando la palabra clave, pero en un movil eso se come la bateria y
/// ademas Android corta el microfono a las aplicaciones de fondo.
///
/// Asi que el trato es otro: **tocas la V y habla**. Un toque para que te oiga,
/// dos toques para abrir la aplicacion entera. Sale mas barato de bateria y es
/// lo que la gente ya espera de un asistente de telefono.
///
/// El nivel de voz que va saliendo se usa para animar la V mientras te oye:
/// que el aura siga tu voz de verdad es lo que hace que parezca viva.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'ajustes.dart';

class Voz {
  Voz._();
  static final Voz instancia = Voz._();

  final SpeechToText _oido = SpeechToText();
  final FlutterTts _boca = FlutterTts();

  bool _oidoListo = false;
  bool _hablando = false;

  /// Lo fuerte que suena la voz ahora, de 0 a 1. Lo lee la V para animarse.
  final ValueNotifier<double> nivel = ValueNotifier(0);

  bool get escuchando => _oido.isListening;
  bool get hablando => _hablando;

  Future<bool> preparar() async {
    if (_oidoListo) return true;

    _oidoListo = await _oido.initialize(
      onError: (e) => nivel.value = 0,
      onStatus: (_) {},
    );

    await _boca.setLanguage('es-ES');
    await _boca.setSpeechRate(0.52); // el ritmo por defecto suena atropellado
    await _boca.setPitch(1.0);
    await _boca.awaitSpeakCompletion(true);

    return _oidoListo;
  }

  /// Escucha una frase y la devuelve. Cadena vacia si no entendio nada.
  Future<String> escuchar({Duration limite = const Duration(seconds: 12)}) async {
    if (!await preparar()) return '';

    // Si VALEN esta hablando, primero se calla: si no, se oye a si mismo.
    await callar();

    final terminado = Completer<String>();
    var ultimo = '';

    await _oido.listen(
      onResult: (resultado) {
        ultimo = resultado.recognizedWords;
        if (resultado.finalResult && !terminado.isCompleted) {
          terminado.complete(ultimo);
        }
      },
      onSoundLevelChange: (db) {
        // El nivel llega en decibelios y va de -2 a 10 mas o menos.
        nivel.value = ((db + 2) / 12).clamp(0.0, 1.0);
      },
      listenOptions: SpeechListenOptions(
        localeId: 'es_ES',
        listenFor: limite,
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
      ),
    );

    // Red de seguridad: si el reconocedor se queda colgado, se sale igual.
    Timer(limite + const Duration(seconds: 2), () {
      if (!terminado.isCompleted) terminado.complete(ultimo);
    });

    final frase = await terminado.future;
    nivel.value = 0;
    return frase.trim();
  }

  Future<void> parar() async {
    await _oido.stop();
    nivel.value = 0;
  }

  /// Dice algo en voz alta. Si la voz esta apagada en ajustes, no dice nada.
  Future<void> hablar(String texto) async {
    if (texto.trim().isEmpty || !Ajustes.vozEncendida) return;

    await preparar();
    _hablando = true;

    // Mientras habla, el nivel se mueve solo para que la V tenga vida. No es
    // el volumen real de la sintesis (Android no lo da), pero acompana.
    final latido = Timer.periodic(const Duration(milliseconds: 90), (t) {
      nivel.value = 0.35 + (t.tick % 7) / 12;
    });

    try {
      await _boca.speak(texto);
    } finally {
      latido.cancel();
      nivel.value = 0;
      _hablando = false;
    }
  }

  Future<void> callar() async {
    if (_hablando) await _boca.stop();
    _hablando = false;
  }
}
