/// Lo que hace falta para que la V sobreviva en Android.
///
/// Android mata sin miramientos lo que corre en segundo plano, y dibujar por
/// encima de otras aplicaciones necesita un permiso aparte que el usuario
/// concede a mano. Aqui esta todo eso junto, para que el resto del codigo no
/// tenga que enterarse.
///
/// Tres cosas, en este orden:
///
/// 1. Pedir el permiso de "mostrar sobre otras aplicaciones".
/// 2. Levantar un servicio en primer plano, con su aviso permanente. Es lo que
///    convence a Android de no matar el proceso.
/// 3. Sacar la burbuja.
///
/// El aviso permanente no se puede quitar: es el precio que pone Android por
/// dejar que algo viva en segundo plano. A cambio, sirve de interruptor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../nucleo/ajustes.dart';

class BurbujaServicio {
  /// Tamano de la ventanita de la burbuja. Se deja holgado sobre la V para que
  /// quepan el halo y el globo de texto sin que Android los recorte.
  static const int anchoVentana = 340;
  static const int altoVentana = 260;

  /// True si el usuario ya dio permiso para dibujar encima de todo.
  static Future<bool> tienePermiso() =>
      FlutterOverlayWindow.isPermissionGranted();

  /// Pide el permiso. Abre los ajustes de Android, no hay otra forma.
  static Future<bool> pedirPermiso() async {
    if (await tienePermiso()) return true;
    return await FlutterOverlayWindow.requestPermission() ?? false;
  }

  /// Prepara el servicio en primer plano. Se llama una vez al arrancar.
  static void prepararServicio() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'valen_fondo',
        channelName: 'VALEN en segundo plano',
        channelDescription:
            'Mantiene viva la V flotante. Android exige este aviso.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: false,
        allowWifiLock: false,
      ),
    );
  }

  /// Enciende la burbuja: permiso, servicio y ventana flotante.
  static Future<bool> encender() async {
    if (!await pedirPermiso()) return false;

    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'VALEN',
        notificationText: 'Toca la V para hablarme',
      );
    }

    if (await FlutterOverlayWindow.isActive()) return true;

    await FlutterOverlayWindow.showOverlay(
      height: altoVentana,
      width: anchoVentana,
      alignment: OverlayAlignment.centerRight,
      flag: OverlayFlag.defaultFlag,
      enableDrag: true,
      positionGravity: PositionGravity.auto,
      overlayTitle: 'VALEN',
      overlayContent: '',
    );

    return true;
  }

  static Future<void> apagar() async {
    await FlutterOverlayWindow.closeOverlay();
    await FlutterForegroundTask.stopService();
  }

  /// Enciende la burbuja al abrir la aplicacion, si el usuario la quiere.
  static Future<void> encenderSiTocaAlArrancar() async {
    if (!Ajustes.burbujaEncendida) return;
    if (!await tienePermiso()) return; // se le pedira desde los ajustes
    await encender();
  }
}

/// Pantalla que explica el permiso antes de mandar al usuario a los ajustes de
/// Android. Un dialogo del sistema sin contexto se deniega casi siempre.
class PermisoBurbuja extends StatelessWidget {
  const PermisoBurbuja({super.key, required this.alTerminar});

  final VoidCallback alTerminar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.layers_outlined, size: 56, color: Color(0xFF5FE3FF)),
              const SizedBox(height: 20),
              const Text(
                'Para que la V pueda flotar',
                style: TextStyle(fontSize: 18, letterSpacing: 1),
              ),
              const SizedBox(height: 12),
              const Text(
                'Android pide permiso aparte para que una aplicacion se dibuje '
                'encima de las demas. Es lo que permite que VALEN este a mano '
                'sin tener que abrir nada.\n\n'
                'Se concede una vez y se puede quitar cuando quieras.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.5, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  await BurbujaServicio.pedirPermiso();
                  alTerminar();
                },
                child: const Text('Dar permiso'),
              ),
              TextButton(onPressed: alTerminar, child: const Text('Ahora no')),
            ],
          ),
        ),
      ),
    );
  }
}
