# VivaCol

Prototipo movil de una plataforma inmobiliaria colaborativa (estilo Waze, pero para
inmuebles): la comunidad mantiene al dia la disponibilidad y fiabilidad de cada
publicacion mediante reportes. Cada aviso tiene un estado tipo semaforo:
verificado (verde), en revision (amarillo) o alerta (naranja/rojo).

Este repositorio es la version inicial con datos de ejemplo (sin backend real).

## Requisitos previos

Antes de empezar necesitas instalar en tu computador:

1. **Flutter SDK** (incluye Dart). Guia oficial: https://docs.flutter.dev/get-started/install
2. **Visual Studio Code**: https://code.visualstudio.com/
3. **Extension de Flutter para VS Code**. En VS Code abre la vista de Extensiones
   (icono de bloques a la izquierda o `Ctrl+Shift+X`), busca "Flutter" e instalala
   (tambien instala Dart automaticamente).
4. **Microsoft Edge** (ya viene instalado en Windows) para ejecutar la app en el navegador.

Para comprobar que Flutter quedo bien instalado, abre una terminal y ejecuta:

```powershell
flutter doctor
```

Debe mostrar visto bueno en "Flutter" y en "Chrome/Edge (web)". No importa si
Android o iOS aparecen con advertencias mientras solo uses el navegador.

## Paso a paso para ejecutar el proyecto

1. **Abre el proyecto en VS Code.**
   Menu `Archivo` > `Abrir carpeta...` y selecciona la carpeta `VivaCol`.

2. **Abre la terminal integrada.**
   Menu `Terminal` > `Nueva terminal` (o `Ctrl+ñ`). La terminal ya se ubica dentro
   de la carpeta del proyecto.

3. **Descarga las dependencias.**
   En la terminal escribe:

   ```powershell
   flutter pub get
   ```

   Esto lee `pubspec.yaml` y baja los paquetes necesarios (por ejemplo `go_router`).

4. **Verifica que Edge esta disponible como dispositivo.**

   ```powershell
   flutter devices
   ```

   En la lista debe aparecer "Edge (web)".

5. **Ejecuta la aplicacion en Edge.**

   ```powershell
   flutter run -d edge
   ```

   Se abrira una ventana de Edge con la app corriendo. La primera vez puede tardar
   un poco mientras compila.

   Alternativa con el mouse: abre el archivo `lib/main.dart`, selecciona el
   dispositivo "Edge" en la barra inferior de VS Code y presiona `F5` (Ejecutar).

6. **Recarga en caliente (hot reload).**
   Mientras la app corre, si cambias algo en el codigo y guardas (`Ctrl+S`),
   los cambios se reflejan al instante. Para detener la app presiona `q` en la
   terminal o el boton de detener en VS Code.

## Ver la app como en un movil

La app esta pensada exclusivamente para vista movil. Para verla asi en Edge:

1. Con la app abierta en Edge, presiona `F12` para abrir las herramientas de desarrollo.
2. Presiona `Ctrl+Shift+M` para activar el modo dispositivo (Toggle device toolbar).
3. En la parte superior elige un telefono (por ejemplo iPhone o Pixel).

Asi se ve con las proporciones de un celular real.

## Como usar la app (recorrido)

1. **Bienvenida:** pantalla inicial con el nombre VivaCol. Pulsa "Comenzar".
2. **Inicio de sesion / registro:** ingresa cualquier correo (con "@") y una clave
   de al menos 4 caracteres. La autenticacion es simulada. Si eliges "registrarme",
   podras seleccionar tu tipo de usuario (busco vivienda / tengo propiedad / agencia).
3. **Listado (Home):** busca por titulo o ubicacion y usa los filtros de ciudad,
   tipo y operacion. Cada tarjeta muestra precio, ubicacion y su etiqueta de estado.
4. **Detalle de propiedad:** toca una tarjeta para ver galeria de fotos, descripcion,
   estado de verificacion e historial de reportes de la comunidad. Abajo tienes los
   botones "Reportar cambio" y "Contactar".
5. **Reportar cambio:** informa si el inmueble sigue disponible, cambio de precio o
   ya no existe. El envio es simulado.
6. **Perfil:** informacion del usuario y, si es agencia o propietario, sus publicaciones.
7. **Publicar propiedad** (solo agencias/propietarios): boton "Publicar" en el Home,
   con formulario de titulo, descripcion, precio, ubicacion, tipo e imagenes (simulado).

Nota: las imagenes de ejemplo se cargan desde internet, asi que necesitas conexion
para verlas. Si no hay conexion, se muestra un icono de imagen no disponible.

## Estructura del proyecto

```
lib/
  main.dart              Punto de entrada de la app
  router/                Rutas centralizadas (go_router)
  theme/                 Colores y tema visual
  models/                Modelos de datos (propiedad, estado, reporte, usuario)
  data/                  Datos de ejemplo (mock)
  utils/                 Utilidades (formato de precios)
  widgets/               Componentes reutilizables (tarjeta, etiqueta de estado)
  screens/               Pantallas (onboarding, login, home, detalle, reporte,
                         perfil, publicar)
```

## Problemas comunes

- Si `flutter run` no encuentra Edge, asegurate de tener Edge instalado y vuelve a
  ejecutar `flutter devices`.
- Si aparecen errores de dependencias, ejecuta de nuevo `flutter pub get`.
- Si algo se rompe tras muchos cambios, prueba `flutter clean` y luego
  `flutter pub get`.
