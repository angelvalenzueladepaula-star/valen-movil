/// En que anda VALEN en cada momento.
///
/// De esto depende como se ve la V y como se comporta la burbuja. Es el mismo
/// ciclo que en la version de escritorio, para que quien conozca uno entienda
/// el otro sin explicaciones.
library;

import 'package:flutter/material.dart';

enum EstadoValen {
  /// En segundo plano. La V respira despacio y apagada, para no molestar.
  dormido,

  /// Te oyo y esta escuchando. La V se abre y el aura sigue tu voz.
  escuchando,

  /// Le llego la pregunta y esta trabajando. Un arco gira a su alrededor.
  pensando,

  /// Esta contestando. Salen ondas de la V al ritmo de lo que dice.
  hablando,

  /// Algo salio mal. Un latido rojo corto y vuelve a dormido.
  error,
}

extension ColoresDeEstado on EstadoValen {
  /// El color con el que se pinta la V en cada estado.
  Color get color => switch (this) {
        EstadoValen.dormido => const Color(0xFF2E7F96),
        EstadoValen.escuchando => const Color(0xFF5FE3FF),
        EstadoValen.pensando => const Color(0xFF7CC4FF),
        EstadoValen.hablando => const Color(0xFFAEEEFF),
        EstadoValen.error => const Color(0xFFFF6B6B),
      };

  /// Cuanto brilla el halo de detras, de 0 a 1.
  double get brillo => switch (this) {
        EstadoValen.dormido => 0.22,
        EstadoValen.escuchando => 0.85,
        EstadoValen.pensando => 0.65,
        EstadoValen.hablando => 1.0,
        EstadoValen.error => 0.7,
      };

  /// Lo rapido que late, en vueltas por segundo.
  double get ritmo => switch (this) {
        EstadoValen.dormido => 0.28,
        EstadoValen.escuchando => 1.0,
        EstadoValen.pensando => 1.9,
        EstadoValen.hablando => 1.4,
        EstadoValen.error => 3.0,
      };

  String get nombre => switch (this) {
        EstadoValen.dormido => 'en segundo plano',
        EstadoValen.escuchando => 'te escucho',
        EstadoValen.pensando => 'pensando',
        EstadoValen.hablando => 'hablando',
        EstadoValen.error => 'algo fallo',
      };
}
