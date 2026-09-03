# VALEN movil

VALEN para Android. **No es el mismo VALEN de la computadora**: es un hermano
suyo, hecho para lo que un telefono hace bien.

El proyecto de escritorio sigue donde estaba y no se toco nada de el. De ahi
solo se trajeron las ideas y la V.

---

## Que cambia respecto al de la computadora

**Lo que se va.** Todo lo que controlaba la maquina: volumen, brillo, abrir
programas, apagar, atajos de teclado, modo gamer, modo viaje. En un telefono no
tiene sentido pedirle a nadie que te suba el brillo cuando tienes la barra
deslizante a un dedo de distancia.

**Lo que se queda, cambiado.**

| | Escritorio | Telefono |
| --- | --- | --- |
| Como aparece | Ventana con logo y espectro | Una V que flota encima de todo |
| Como se le habla | Micro siempre abierto, palabra clave | Tocas la V y hablas |
| Quien lo usa | Solo Sebas, por su voz | Cuenta de usuario, cada uno la suya |
| Modo seguridad | Bloquea el PC, alarma, webcam | Vigila el telefono, otra cosa |
| Saludo del dia | Igual | Igual |

**Lo que llega nuevo, y es el motivo de todo esto:** VALEN **ve**. En el
telefono la camara esta a mano, asi que el uso natural no es "abre Discord"
sino **mandarle una foto de los ejercicios y que los resuelva**. Varias fotos a
la vez, porque un examen tiene varias hojas.

Y **todo queda guardado**, como en cualquier asistente al que estas
acostumbrado: cada conversacion con su titulo, y ahi sigue cuando vuelvas.

---

## El historial

Se comporta como esperas de una IA normal:

- Cada conversacion se guarda entera, con sus fotos.
- El titulo se pone solo, sacado de la primera pregunta.
- Al abrir la aplicacion vuelves a lo ultimo que estabas haciendo.
- El cajon lateral las lista, y el buscador **mira dentro de lo que se dijo**,
  no solo en los titulos: uno recuerda "aquella vez que le pregunte por las
  derivadas", no el nombre que le puso.
- Se pueden renombrar y borrar. Al borrar una, se van tambien sus fotos.

Vive en una base SQLite dentro del telefono, no en un servidor. El historial se
lee cada vez que abres la aplicacion y cada vez que escribes: hacerlo contra un
servidor seria lento, gastaria datos y dejaria de funcionar sin cobertura.

Las fotos se guardan como archivos y en la base solo queda su ruta. Meter una
foto de dos megas en cada fila haria que la base creciera hasta arrastrarse.

---

## Las tareas con fotos

Al adjuntar fotos salen cuatro botones, que son las cuatro cosas que de verdad
se piden al estudiar:

| Boton | Que le pide |
| --- | --- |
| Resolver todo | El resultado de cada pregunta y una linea de por que |
| Paso a paso | La explicacion entera, como a alguien que no lo entiende |
| Solo respuestas | Numeradas y sin explicar, para copiar rapido |
| **Revisar lo mio** | Mira las respuestas que ya escribiste y dice cuales estan mal |

VALEN empieza diciendo cuantas preguntas ve, para que sepas que no se le
escapo ninguna, y si algo de la foto no se lee lo dice en vez de inventarselo.

**Las fotos viejas no se reenvian en cada mensaje.** Solo las del ultimo
mensaje que llevaba. Reenviar cada foto de la conversacion en cada turno
multiplicaria el gasto por nada, pero perderlas del todo romperia el caso
normal: mandar la tarea y luego preguntar por la tercera pregunta.

---

## La V flotante

En vez de abrir una aplicacion a pantalla completa para hablarle, la V vive
encima de lo que estes haciendo, pequena y medio transparente.

| Gesto | Que hace |
| --- | --- |
| Un toque | Te escucha y contesta ahi mismo |
| **Dos toques** | Abre la aplicacion entera |
| Arrastrar | La mueves donde quieras |
| Toque largo | La manda a dormir |

Y **cambia segun lo que este haciendo**, como el asistente del iPhone:

- **En segundo plano**: respira despacio, apagada, no molesta.
- **Te escucha**: se abre, y el aura sigue tu voz de verdad, no una animacion
  cualquiera.
- **Pensando**: un arco gira a su alrededor.
- **Hablando**: salen ondas de la V.
- **Algo fallo**: un latido rojo corto.

La V no es una imagen: son sus contornos en vectores, cuarenta y dos puntos
sacados del logo original. Por eso se puede deformar, encender el borde y
dibujar trazo a trazo, y por eso se ve igual de nitida en la burbuja de sesenta
pixeles que a pantalla completa.

---

## Como sacarlo: dos caminos, los dos gratis

Android Studio y el SDK de Android **son gratis**. Lo unico que cuesta dinero
en Android es publicar en Play Store, veinticinco dolares una vez, y eso no
hace falta para instalarte la aplicacion en tu propio telefono.

Lo que si cuesta son ocho gigas de disco. De ahi los dos caminos.

### Camino A: la web, sin instalar nada

Es la misma aplicacion compilada para el navegador. Se publica sola en GitHub
Pages con el flujo `.github/workflows/web.yml`:

1. Subir el proyecto a un repositorio de GitHub (gratis).
2. Settings, Pages, y en Source elegir "GitHub Actions".
3. Cada cambio republica la pagina.

Desde el movil se abre la direccion y se le da a "Anadir a pantalla de inicio":
queda con su icono de la V y se abre a pantalla completa, como una aplicacion.

**Lo que la web NO puede hacer: la V flotante.** Ninguna pagina web puede
dibujarse encima de otras aplicaciones del telefono. No es un limite de VALEN,
es como funcionan los navegadores, y no hay forma de saltarselo.

Todo lo demas si: conversar, mandar fotos de la tarea, el historial guardado,
la voz, las cuentas.

### Camino B: el APK, compilado en la nube

Para tener la V flotante de verdad hace falta el APK, pero **no hace falta
instalarse el SDK**: lo compila GitHub con el flujo `.github/workflows/apk.yml`.

1. Subir el proyecto a GitHub.
2. Pestana "Actions", elegir "APK de VALEN", "Run workflow".
3. Cuando acabe, el APK esta abajo en "Artifacts".
4. Se pasa al telefono y se instala.

Tarda unos minutos por compilacion, que es la pega frente a tenerlo en casa.

### Camino C: instalarse el SDK

Si algun dia quieres iterar rapido, Android Studio de
<https://developer.android.com/studio> lo instala todo solo: el SDK, las
licencias y el Java correcto. Son unos ocho gigas.

Lo que gana: `adb`, que deja conectar el telefono por cable y ver los cambios
al momento en vez de esperar una compilacion en la nube cada vez.

```bash
flutter doctor --android-licenses
flutter build apk --release
```

El APK queda en `buildpp\outputslutter-apkpp-release.apk`.

### Para ver la pantalla mientras tanto

```bash
flutter run -d chrome
```

## Lo que hay que configurar

### La clave del cerebro

Se saca gratis en <https://aistudio.google.com/apikey> y **se escribe dentro de
la aplicacion**, en Ajustes. No va en el codigo a proposito: una clave metida
en un APK se saca en cinco minutos con cualquier herramienta, y quien la saque
gasta tu cuota. Escrita en los ajustes, se guarda cifrada en el llavero del
propio Android.

Sin clave, VALEN abre y se deja configurar, pero no puede pensar.

### Las cuentas de usuario (opcional)

Para que cada quien tenga su memoria hace falta un servidor de cuentas. Se usa
Supabase, que es PostgreSQL con registro de usuarios incluido, gratis y sin
tarjeta:

1. Crear proyecto en <https://supabase.com>.
2. En el editor de SQL, crear la tabla y la regla de seguridad:

```sql
create table hechos (
  usuario     uuid references auth.users not null,
  clave       text not null,
  valor       text not null,
  confianza   real default 0.8,
  actualizado timestamptz default now(),
  primary key (usuario, clave)
);

alter table hechos enable row level security;

-- Esta regla es la que de verdad protege los datos: cada quien ve los suyos.
create policy "cada uno lo suyo" on hechos
  for all using (auth.uid() = usuario) with check (auth.uid() = usuario);
```

3. Compilar pasandole los datos del proyecto:

```bash
flutter build apk --release --dart-define=SUPABASE_URL=https://loquesea.supabase.co --dart-define=SUPABASE_ANON=la_clave_publica
```

**La clave "anon" de Supabase si puede ir en la aplicacion**: esta pensada para
eso y no da acceso a nada por si sola. Quien protege los datos es la regla de
arriba, en el servidor. Sin esa regla, cualquiera podria leer la memoria de
todos: no te saltes el paso.

Sin configurar nada de esto, VALEN funciona igual pero lo que aprenda se queda
solo en ese telefono.

---

## Permisos que pedira, y por que

| Permiso | Para que |
| --- | --- |
| Microfono | Oirte |
| Camara | Fotos de ejercicios |
| **Mostrar sobre otras aplicaciones** | Que la V pueda flotar |
| Notificaciones | El aviso permanente que exige Android |
| Arrancar al encender | Volver despues de reiniciar |

El de "mostrar sobre otras aplicaciones" es especial: no sale el dialogo normal
de Android, hay que ir a los ajustes. Por eso la aplicacion lo explica antes de
mandarte alli; un dialogo del sistema sin contexto lo deniega casi todo el
mundo.

**El aviso permanente no se puede quitar.** Es el precio que pone Android por
dejar que algo viva en segundo plano. Sin el, mata la burbuja a los pocos
minutos.

---

## Como esta hecho por dentro

```
lib/
  main.dart                 arranque y a que pantalla se va
  nucleo/
    logo.dart               la V en vectores, 42 puntos
    historial.dart          las conversaciones guardadas
    estados.dart            dormido / escuchando / pensando / hablando / error
    cerebro.dart            Gemini, con imagenes
    voz.dart                oir y hablar
    sesion.dart             cuentas de usuario
    memoria.dart            lo que VALEN aprende de ti
    ajustes.dart            lo que se configura una vez
  burbuja/
    v_animada.dart          la V viva, dibujada a mano sobre un lienzo
    burbuja.dart            la ventana flotante y sus gestos
  pantallas/
    entrar.dart             entrar o crear cuenta
    conversaciones.dart     el cajon con todo lo guardado
    chat.dart               la aplicacion entera: hablar y mandar fotos
    ajustes_pantalla.dart   ajustes
  servicios/
    burbuja_servicio.dart   permisos y servicio en primer plano
```

**Dos aplicaciones en una.** La burbuja corre en un motor de Flutter aparte del
resto: son dos procesos que no comparten memoria viva y se hablan por mensajes.
Por eso la burbuja no puede llamar a una funcion de la aplicacion, tiene que
mandarle un aviso.

**El telefono no escucha todo el rato.** En la computadora el microfono esta
siempre abierto esperando su nombre. En un telefono eso se come la bateria y
ademas Android le corta el microfono a lo que corre en segundo plano. De ahi el
trato distinto: tocas la V y habla.

---

## Lo que falta

Escrito y probado: la V animada, el cerebro con imagenes, la voz, las cuentas,
la memoria, el historial de conversaciones, la burbuja, los ajustes, los
permisos, y los dos flujos que compilan el APK y publican la web.

Queda por hacer:

- **Saludo de la manana** adaptado al telefono (hora, clima, bateria, y lo que
  tengas pendiente).
- **Modo seguridad de telefono**, que es otra cosa que en el PC: foto con la
  camara frontal si alguien falla el desbloqueo, alarma si mueven el telefono
  mientras esta vigilando, y aviso si lo desenchufan.
- Probarlo todo en un telefono de verdad, que es donde se ven los problemas
  que no salen en el navegador.
