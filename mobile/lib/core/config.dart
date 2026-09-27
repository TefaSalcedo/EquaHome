/// Configuración de entorno.
///
/// En el emulador de Android el backend del host es `10.0.2.2`; en iOS
/// simulator y desktop es `localhost`. Sobrescribir con:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000`
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);
