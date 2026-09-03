/// La V de VALEN, en vectores.
///
/// Son los contornos del logo original, trazados y simplificados a 42 puntos.
/// Va en vectores y no como imagen porque asi se puede animar de verdad:
/// dibujarla trazo a trazo, recorrer su borde con un brillo, deformarla. Una
/// imagen solo se puede escalar y girar.
///
/// Las coordenadas van de 0 a 1 sobre el lado mas largo, asi que la V se ve
/// igual de nitida en la burbuja de sesenta pixeles y a pantalla completa.
library;

import 'dart:ui';

/// Silueta de la V: pares (x, y) entre 0 y 1.
const List<double> siluetaV = [
  0.0299, 0.0025, 0.1061, 0.0362, 0.1474, 0.0705, 0.169, 0.1233,
  0.176, 0.169, 0.1709, 0.1709, 0.1093, 0.0724, 0.0648, 0.0432,
  0.0197, 0.1086, 0.0025, 0.1741, 0.0013, 0.2116, 0.0095, 0.244,
  0.0394, 0.3119, 0.0985, 0.3748, 0.0686, 0.2878, 0.0623, 0.2001,
  0.0883, 0.1366, 0.0997, 0.1258, 0.1156, 0.1226, 0.1328, 0.1404,
  0.4924, 0.7268, 0.5006, 0.7224, 0.8806, 0.1302, 0.8964, 0.1264,
  0.9288, 0.162, 0.9409, 0.202, 0.9346, 0.284, 0.9003, 0.3793,
  0.9314, 0.3532, 0.9593, 0.3177, 0.9892, 0.2554, 0.9975, 0.209,
  0.9943, 0.1518, 0.9701, 0.0858, 0.9327, 0.0375, 0.9034, 0.0102,
  0.7802, 0.0121, 0.7656, 0.0222, 0.4968, 0.4511, 0.2446, 0.0273,
  0.2287, 0.0102, 0.2141, 0.0044,
];

/// Arma el trazado de la V dentro de un cuadrado del lado pedido.
Path trazadoV(double lado) {
  final camino = Path();

  for (var i = 0; i < siluetaV.length; i += 2) {
    final x = siluetaV[i] * lado;
    final y = siluetaV[i + 1] * lado;
    if (i == 0) {
      camino.moveTo(x, y);
    } else {
      camino.lineTo(x, y);
    }
  }

  return camino..close();
}

/// Alto de la V cuando su ancho vale [lado]. El logo no es cuadrado.
double altoV(double lado) {
  var maximo = 0.0;
  for (var i = 1; i < siluetaV.length; i += 2) {
    if (siluetaV[i] > maximo) maximo = siluetaV[i];
  }
  return lado * maximo;
}
