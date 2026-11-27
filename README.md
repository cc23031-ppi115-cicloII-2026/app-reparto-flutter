# Swoosh Reparto

Aplicación Flutter para gestión de pedidos y rutas de reparto. Los pedidos y
las operaciones pendientes se guardan localmente; el backend Rust solo recibe
los cambios cuando la API vuelve a estar disponible.

## Plataformas

- Android e iOS: almacenamiento local mediante sqflite nativo.
- macOS: almacenamiento local mediante sqflite.
- Linux y Windows: almacenamiento local SQLite mediante FFI.
- Web: SQLite persistido en IndexedDB mediante `sqflite_common_ffi_web`.

En Web, `web/sqlite3.wasm` y `web/sqflite_sw.js` son necesarios para que el
almacenamiento persistente funcione y ya forman parte del proyecto.

## Ejecutar

La URL predeterminada de la API es `http://localhost:8080`, salvo Android
emulado, donde se usa `http://10.0.2.2:8080`. Para otro host, pasa la URL al
compilar o ejecutar:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:8080
flutter run -d linux --dart-define=API_URL=http://localhost:8080
flutter run -d <device-id> --dart-define=API_URL=http://<host-accesible>:8080
```

En un dispositivo físico, `<host-accesible>` debe ser la dirección LAN del
equipo donde corre el backend. Usa `flutter devices` para consultar los IDs
disponibles.

## Uso sin conexión

Después de iniciar sesión correctamente al menos una vez, la sesión y los
pedidos descargados se conservan localmente. Las entregas y los nuevos pedidos
se guardan en la cola local mientras la API no responda. Al recuperar conexión,
la app sincroniza al detectar la red o mediante una comprobación cada 15
segundos mientras permanece abierta; después actualiza los pedidos visibles.

## Validación

```bash
flutter analyze
flutter test
flutter build web
flutter build linux
flutter build apk
```
