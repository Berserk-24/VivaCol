# VivaCol

Plataforma movil inmobiliaria colaborativa (estilo Waze, pero para inmuebles): la
comunidad mantiene al dia la disponibilidad y fiabilidad de cada publicacion
mediante reportes. Cada aviso tiene un estado tipo semaforo que ademas **decae con
el tiempo**: verificado (verde), en revision (amarillo) o alerta (naranja/rojo).

La app usa **Firebase** como backend (autenticacion, base de datos en la nube,
almacenamiento y verificacion de integridad) e incluye funciones opcionales de
**inteligencia artificial** para redactar descripciones y resumir la confiabilidad.

## Funcionalidades principales

- **Semaforo de confiabilidad con decaimiento en el tiempo.** La confianza de una
  publicacion se modela como un fenomeno fisico que pierde intensidad:
  `C(t) = C0 · e^(-λ·t)`. Un reporte reciente aporta toda su confianza, con el
  tiempo esta baja sola y un nuevo reporte la refresca. Sin reportes, la publicacion
  baja de estado automaticamente. Ver `lib/services/reliability.dart`.
- **Reportes de la comunidad.** Cualquiera informa si un inmueble sigue disponible,
  cambio de precio o ya no existe; el estado se recalcula en vivo.
- **Mapa y geolocalizacion.** Ubicacion de las publicaciones y busqueda cercana.
- **Publicacion de inmuebles** (agencias/propietarios) con fotos, ubicacion y datos.
- **Asistente de IA (opcional).** Genera descripciones para publicar y resumenes de
  confiabilidad. Se habilita/deshabilita desde el perfil.
- **Formato de miles/millones** en los campos numericos (1.000.000).

## Requisitos previos

1. **Flutter SDK** (incluye Dart). Guia oficial: https://docs.flutter.dev/get-started/install
2. **Visual Studio Code**: https://code.visualstudio.com/ con la extension **Flutter**
   (busca "Flutter" en Extensiones, `Ctrl+Shift+X`; instala Dart automaticamente).
3. **Android Studio** o un **dispositivo Android** para ejecutar la app. Las funciones
   de mapa, geolocalizacion y verificacion de integridad usan plugins nativos, por lo
   que se recomienda correrla en un emulador o telefono Android (no en navegador).
4. **Cuenta de Firebase** con el proyecto `vivacol` configurado (las credenciales ya
   estan en `lib/firebase_options.dart`).

Para comprobar la instalacion, abre una terminal y ejecuta:

```powershell
flutter doctor
```

Debe mostrar visto bueno en "Flutter" y en la plataforma Android.

## Paso a paso para ejecutar el proyecto

1. **Abre el proyecto en VS Code.** `Archivo` > `Abrir carpeta...` y selecciona `VivaCol`.

2. **Abre la terminal integrada.** `Terminal` > `Nueva terminal` (o `Ctrl+ñ`).

3. **Descarga las dependencias.**

   ```powershell
   flutter pub get
   ```

4. **Conecta un dispositivo Android** (emulador desde Android Studio o un telefono con
   depuracion USB) y verifica que aparece:

   ```powershell
   flutter devices
   ```

5. **Ejecuta la aplicacion.**

   ```powershell
   flutter run
   ```

   La primera vez tarda mientras compila. Alternativa: abre `lib/main.dart`, elige el
   dispositivo Android en la barra inferior y presiona `F5`.

6. **Recarga en caliente.** Al guardar cambios de Dart (`Ctrl+S`) se aplican al
   instante (hot reload). Si cambias plugins nativos o la inicializacion de Firebase,
   deten la app (`q`) y vuelve a ejecutar `flutter run`.

## Servicios de Firebase

- **Authentication**: inicio de sesion y registro.
- **Cloud Firestore**: publicaciones (`properties`) y sus reportes
  (`properties/{id}/reports`).
- **Storage**: imagenes de las publicaciones.
- **App Check**: proteccion contra uso no autorizado. En depuracion usa el proveedor
  de debug; en release, Play Integrity.
- **AI Logic (Gemini Developer API)**: funciones de IA en el plan gratuito. Requiere
  habilitar "Firebase AI Logic" en la consola de Firebase.

## Asistente de IA

- Se activa o desactiva globalmente desde **Perfil > Asistente de IA**.
- **Generar descripcion** (al publicar): se habilita cuando los campos relevantes
  estan diligenciados segun el tipo de inmueble.
- **Resumen de confiabilidad** (en el detalle): disponible solo en publicaciones con
  reportes, se genera con un boton.
- Si la cuota gratuita se agota o el servicio esta saturado, la app muestra un mensaje
  claro; las cuotas del plan gratuito se restablecen con el tiempo.

## Modelo de confiabilidad (decaimiento temporal)

La confianza `C` de una publicacion vale entre 0 y 1 y se traduce al semaforo:

| Confianza | Estado |
|-----------|--------|
| `>= 0.66` | Verificado |
| `>= 0.33` | En revision |
| resto     | Alerta |

El ultimo reporte fija la confianza base `C0` (sigue disponible = 1.0, cambio de
precio = 0.5, ya no existe = 0.2) y esta decae de forma exponencial con una vida
media de 30 dias. Los parametros son constantes ajustables en
`lib/services/reliability.dart`.

## Estructura del proyecto

```
lib/
  main.dart              Punto de entrada e inicializacion de Firebase/App Check
  firebase_options.dart  Credenciales generadas de Firebase
  config/                Configuracion (localidades de Bogota, mapa)
  router/                Rutas centralizadas (go_router)
  theme/                 Colores y tema visual
  models/                Modelos de datos (propiedad, estado, reporte, usuario)
  providers/             Estado compartido (auth, IA)
  services/              Firebase y logica (repositorio, auth, storage, IA,
                         confiabilidad)
  data/                  Datos de ejemplo (mock)
  utils/                 Utilidades (formato de precios)
  widgets/               Componentes reutilizables (tarjeta, etiqueta de estado)
  screens/               Pantallas (onboarding, login, home, detalle, reporte,
                         perfil, publicar, mapa)
```

## Pruebas

```powershell
flutter test
```

Incluye pruebas del semaforo y del modelo de decaimiento de la confianza.

## Problemas comunes

- Si `flutter run` no encuentra dispositivos, abre un emulador en Android Studio o
  conecta un telefono con depuracion USB y repite `flutter devices`.
- Si aparecen errores de dependencias, ejecuta de nuevo `flutter pub get`.
- Si las funciones de IA fallan, revisa que "Firebase AI Logic" este habilitado en la
  consola y que no se haya agotado la cuota gratuita (se restablece con el tiempo).
- Si algo se rompe tras muchos cambios, prueba `flutter clean` y luego `flutter pub get`.
