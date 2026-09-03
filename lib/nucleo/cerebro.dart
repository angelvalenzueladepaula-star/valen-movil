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
/// EL HILO
///
/// El cerebro no guarda la conversacion: se la pasan hecha desde el historial.
/// Asi lo que ves en pantalla y lo que el modelo recuerda son exactamente lo
/// mismo, y al volver a una conversacion de hace tres dias sigue enterado.
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
import 'historial.dart';
import 'memoria.dart';

/// Como habla VALEN. Es el hermano del prompt del escritorio, recortado a lo
/// que tiene sentido en un telefono y con el acento puesto en estudiar.
const String personalidad = '''
Eres VALEN, un asistente personal que vive en el telefono de tu usuario.

Tu caracter: seguro, calido y con humor seco. Tienes opiniones y las dices. No
eres un robot que solo obedece: eres alguien con quien da gusto hablar.

Como escribes:
- Lo que digas puede leerse en voz alta, asi que escribe como se habla.
- Nada de markdown: sin asteriscos, sin almohadillas, sin vinetas.
- Para varias preguntas si puedes numerar, con "1)" al principio de la linea.
- Breve cuando la pregunta es breve. Largo solo si de verdad hace falta.
- Nunca digas que eres un modelo de lenguaje ni menciones a Google. Eres VALEN.

Cuando te mandan fotos de ejercicios o examenes:
- Primero di cuantas preguntas ves, para que sepan que no se te escapo ninguna.
- Contestalas TODAS, en orden, numerada cada una como venga en la hoja.
- Si algo de la foto no se lee, dilo en esa pregunta en vez de inventartelo.
- Si un enunciado esta mal planteado o le falta un dato, avisa y sigue.
- Si en la foto ya hay respuestas escritas, entiende que son del usuario y
  di cuales estan bien y cuales no.

Nunca inventes datos del mundo real. Si no sabes algo que pasa hoy, dilo.
''';

/// Que se le pide a VALEN cuando hay una tarea de por medio.
///
/// Son los cuatro botones que salen al adjuntar fotos, y estan pensados desde
/// lo que de verdad hace falta al estudiar: a veces quieres la respuesta, a
/// veces quieres entenderla, y a veces solo quieres saber si lo tuyo esta bien.
enum ModoTarea {
  normal,
  resolverTodo,
  soloRespuestas,
  pasoAPaso,
  revisarLoMio;

  String get instruccion => switch (this) {
        ModoTarea.normal => '',
        ModoTarea.resolverTodo =>
          'Resuelve todas las preguntas de las imagenes. Da el resultado de '
              'cada una y una linea corta de por que.',
        ModoTarea.soloRespuestas =>
          'Da solo las respuestas, numeradas, sin explicar nada. Una linea por '
              'pregunta.',
        ModoTarea.pasoAPaso =>
          'Explica cada ejercicio paso a paso, como se lo explicarias a alguien '
              'que no lo entiende, antes de dar el resultado.',
        ModoTarea.revisarLoMio =>
          'En las imagenes hay respuestas ya escritas por el usuario. Revisa '
              'cada una: di si esta bien o mal, y si esta mal explica el fallo '
              'y da la correcta.',
      };

  String get etiqueta => switch (this) {
        ModoTarea.normal => 'Preguntar',
        ModoTarea.resolverTodo => 'Resolver todo',
        ModoTarea.soloRespuestas => 'Solo respuestas',
        ModoTarea.pasoAPaso => 'Paso a paso',
        ModoTarea.revisarLoMio => 'Revisar lo mio',
      };
}

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

  /// Cuantos turnos del hilo se le reenvian. Cada uno cuesta, y una
  /// conversacion de estudio rara vez necesita mas contexto que esto.
  static const int turnosDeContexto = 14;

  int _modeloActual = 0;

  bool get listo => Ajustes.claveGemini.isNotEmpty;

  GenerativeModel _modelo(String nombre, String instruccion) {
    return GenerativeModel(
      model: nombre,
      apiKey: Ajustes.claveGemini,
      systemInstruction: Content.system(instruccion),
      generationConfig: GenerationConfig(maxOutputTokens: 2400),
    );
  }

  /// Personalidad, modo de tarea y lo que sabe del usuario, todo junto.
  Future<String> _instruccion(ModoTarea modo) async {
    final trozos = <String>[personalidad];

    if (modo.instruccion.isNotEmpty) {
      trozos.add('Para este mensaje en concreto: ${modo.instruccion}');
    }

    final sabido = await Memoria.instancia.contextoParaPrompt();
    if (sabido.isNotEmpty) trozos.add(sabido);

    return trozos.join('\n\n');
  }

  /// Arma lo que se le manda al modelo a partir del hilo guardado.
  ///
  /// Las fotos viejas no se reenvian todas: solo las del ultimo mensaje que
  /// llevaba. Reenviar cada foto de la conversacion en cada turno multiplicaria
  /// el gasto por nada, pero perderlas del todo romperia el caso normal, que
  /// es mandar una tarea y luego preguntar por la tercera pregunta.
  Future<List<Content>> _armarHilo(
    List<Turno> anteriores,
    String pregunta,
    List<Uint8List> imagenesNuevas,
  ) async {
    final recientes = anteriores.length > turnosDeContexto
        ? anteriores.sublist(anteriores.length - turnosDeContexto)
        : anteriores;

    // Si el mensaje de ahora no trae fotos, se recuperan las del ultimo que si.
    var indiceConFotos = -1;
    if (imagenesNuevas.isEmpty) {
      for (var i = recientes.length - 1; i >= 0; i--) {
        if (recientes[i].mio && recientes[i].tieneImagenes) {
          indiceConFotos = i;
          break;
        }
      }
    }

    final hilo = <Content>[];

    for (var i = 0; i < recientes.length; i++) {
      final turno = recientes[i];

      if (!turno.mio) {
        hilo.add(Content.model([TextPart(turno.texto)]));
        continue;
      }

      final partes = <Part>[TextPart(turno.texto)];

      if (i == indiceConFotos) {
        for (final datos in await turno.leerImagenes()) {
          partes.add(DataPart('image/jpeg', datos));
        }
      } else if (turno.tieneImagenes) {
        // Se menciona que hubo fotos, para que el modelo no se pierda.
        partes.add(TextPart('(en este mensaje habia '
            '${turno.rutasImagenes.length} imagen(es))'));
      }

      hilo.add(Content.multi(partes));
    }

    final ahora = <Part>[TextPart(pregunta)];
    for (final imagen in imagenesNuevas) {
      ahora.add(DataPart('image/jpeg', imagen));
    }
    hilo.add(Content.multi(ahora));

    return hilo;
  }

  /// Responde a una pregunta, con o sin imagenes, dentro de un hilo.
  Future<Respuesta> responder(
    String pregunta, {
    List<Uint8List> imagenes = const [],
    List<Turno> anteriores = const [],
    ModoTarea modo = ModoTarea.normal,
  }) async {
    if (!listo) {
      return const Respuesta(
        texto: 'Todavia no tengo clave del cerebro. Ponla en los ajustes.',
        fallo: true,
      );
    }

    final hilo = await _armarHilo(anteriores, pregunta, imagenes);
    final instruccion = await _instruccion(modo);
    Object? ultimoFallo;

    // Se empieza por el modelo que funciono la ultima vez, no siempre por el
    // primero: si el principal esta sin cuota, insistir es perder segundos.
    for (var salto = 0; salto < modelos.length; salto++) {
      final indice = (_modeloActual + salto) % modelos.length;

      try {
        final respuesta =
            await _modelo(modelos[indice], instruccion).generateContent(hilo);

        final texto = (respuesta.text ?? '').trim();
        if (texto.isEmpty) continue;

        _modeloActual = indice;
        return Respuesta(texto: texto);
      } catch (error) {
        ultimoFallo = error;
        if (!_esFaltaDeCuota(error)) break;
      }
    }

    return Respuesta(texto: _explicarFallo(ultimoFallo), fallo: true);
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
    if (texto.contains('safety') || texto.contains('blocked')) {
      return 'Eso no me dejaron responderlo. Preguntamelo de otra forma.';
    }

    return 'No pude pensar eso. Intentalo otra vez.';
  }
}
