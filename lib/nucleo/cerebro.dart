/// El cerebro de VALEN en el telefono.
///
/// Es el mismo modelo que en la version de escritorio, pero con una diferencia
/// que aqui lo cambia todo: **puede ver**. En el telefono la camara esta a
/// mano, asi que el uso natural no es "abre Discord" sino "mira esta hoja de
/// ejercicios y resuelvemela".
///
/// Por eso desaparecen las herramientas que controlaban la maquina. En su
/// lugar hay dos cosas que en un telefono valen mucho mas:
///
/// - **Leer imagenes**: fotos de apuntes, cuestionarios, pizarras, enunciados.
/// - **Contestar de seguido**: varias preguntas en una y las responde todas.
///
/// LA CLAVE
///
/// La clave de Gemini NO va escrita en el codigo. Una clave metida dentro de
/// un APK se saca en cinco minutos con cualquier herramienta, y el que la saque
/// gasta tu cuota. Aqui la escribe el usuario una vez en los ajustes y se
/// guarda cifrada en el llavero del propio Android.
library;

import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';

import 'ajustes.dart';
import 'memoria.dart';

/// Como habla VALEN. Es el hermano del prompt del escritorio, recortado a lo
/// que tiene sentido en un telefono y con el acento puesto en estudiar.
const String personalidad = '''
Eres VALEN, un asistente personal que vive en el telefono de tu usuario.

Tu caracter: seguro, calido y con humor seco. Tienes opiniones y las dices. No
eres un robot que solo obedece: eres alguien con quien da gusto hablar.

Como hablas:
- Tu respuesta se lee en voz alta, asi que escribe como se habla.
- Sin markdown, sin asteriscos, sin vinetas ni listas numeradas.
- Breve: una o dos frases, salvo que te pidan una explicacion de verdad.
- Los numeros y simbolos, como se pronuncian: "ochenta por ciento", no "80%".
- Nunca digas que eres un modelo de lenguaje ni menciones a Google. Eres VALEN.

Cuando te mandan ejercicios o examenes:
- Resuelvelos de verdad, paso a paso, pero contando el razonamiento como se lo
  contarias a un companero, no como un libro de texto.
- Si son varias preguntas, contestalas todas, en orden y numeradas al hablar
  ("la primera...", "la segunda...").
- Si en la foto no se lee algo, dilo en vez de inventartelo.
- Si te piden solo el resultado, da el resultado. Si te piden que expliques,
  explica.
- Si el ejercicio esta mal planteado o le falta un dato, avisa.

Nunca inventes datos del mundo real. Si no sabes algo que pasa hoy, dilo.
''';

/// Lo que VALEN devuelve tras pensar.
class Respuesta {
  const Respuesta({required this.texto, this.fallo = false});

  final String texto;
  final bool fallo;
}

class Cerebro {
  Cerebro._();
  static final Cerebro instancia = Cerebro._();

  /// El plan gratuito da pocas peticiones al dia por modelo. Cuando el primero
  /// se agota se pasa al siguiente, igual que en la version de escritorio.
  static const List<String> modelos = [
    'gemini-3.6-flash',
    'gemini-flash-latest',
    'gemini-3.1-flash-lite',
  ];

  final List<Content> _historial = [];
  int _modeloActual = 0;

  /// Cuantos turnos de conversacion se recuerdan. En un telefono el hilo es
  /// corto por naturaleza, y cada turno guardado se reenvia y cuesta.
  static const int turnosRecordados = 12;

  bool get listo => Ajustes.claveGemini.isNotEmpty;

  /// Olvida la conversacion, no la memoria a largo plazo.
  void olvidarHilo() => _historial.clear();

  GenerativeModel _modelo(String nombre, String instruccion) {
    return GenerativeModel(
      model: nombre,
      apiKey: Ajustes.claveGemini,
      systemInstruction: Content.system(instruccion),
      generationConfig: GenerationConfig(maxOutputTokens: 1400),
    );
  }

  /// Lo que sabe del usuario, para que no empiece de cero cada vez.
  Future<String> _instruccion() async {
    final sabido = await Memoria.instancia.contextoParaPrompt();
    return sabido.isEmpty ? personalidad : '$personalidad\n\n$sabido';
  }

  /// Responde a una pregunta, con o sin imagenes.
  ///
  /// [imagenes] son fotos de apuntes o ejercicios. Van con la pregunta en el
  /// mismo turno, que es como el modelo las entiende mejor.
  Future<Respuesta> responder(String pregunta, {List<Uint8List> imagenes = const []}) async {
    if (!listo) {
      return const Respuesta(
        texto: 'Todavia no tengo clave del cerebro. Ponla en los ajustes.',
        fallo: true,
      );
    }

    final partes = <Part>[TextPart(pregunta)];
    for (final imagen in imagenes) {
      partes.add(DataPart('image/jpeg', imagen));
    }

    _historial.add(Content.multi(partes));
    _recortarHilo();

    final instruccion = await _instruccion();
    Object? ultimoFallo;

    // Se empieza por el modelo que funciono la ultima vez, no siempre por el
    // primero: si el principal esta sin cuota, insistir es perder segundos.
    for (var salto = 0; salto < modelos.length; salto++) {
      final indice = (_modeloActual + salto) % modelos.length;

      try {
        final respuesta = await _modelo(modelos[indice], instruccion)
            .generateContent(_historial);

        final texto = (respuesta.text ?? '').trim();
        if (texto.isEmpty) continue;

        _modeloActual = indice;
        _historial.add(Content.model([TextPart(texto)]));
        return Respuesta(texto: texto);
      } catch (error) {
        ultimoFallo = error;
        if (!_esFaltaDeCuota(error)) break;
      }
    }

    // El turno que fallo se saca del hilo: si se queda, envenena los
    // siguientes reenviandose una y otra vez.
    _historial.removeLast();
    return Respuesta(texto: _explicarFallo(ultimoFallo), fallo: true);
  }

  void _recortarHilo() {
    while (_historial.length > turnosRecordados * 2) {
      _historial.removeAt(0);
    }
  }

  bool _esFaltaDeCuota(Object error) {
    final texto = error.toString().toLowerCase();
    return texto.contains('429') ||
        texto.contains('quota') ||
        texto.contains('resource_exhausted') ||
        texto.contains('rate limit');
  }

  String _explicarFallo(Object? error) {
    final texto = (error ?? '').toString().toLowerCase();

    if (texto.contains('api key') || texto.contains('api_key') || texto.contains('401')) {
      return 'La clave del cerebro no vale. Revisala en los ajustes.';
    }
    if (_esFaltaDeCuota(error ?? '')) {
      return 'Me quede sin cuota por hoy. Manana vuelvo a estar entero.';
    }
    if (texto.contains('socket') || texto.contains('network') || texto.contains('failed host')) {
      return 'No tengo internet ahora mismo.';
    }

    return 'No pude pensar eso. Intentalo otra vez.';
  }
}
