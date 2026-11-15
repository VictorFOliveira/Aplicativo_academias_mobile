# Cactus Fight Mobile

App Flutter para o cadastro inicial da academia. Requer Flutter 3.41.9 ou uma versão compatível com Dart 3.11.5. A API e o PostgreSQL ficam no backend.

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://api.exemplo.com
```

Para desenvolvimento com o emulador Android e a API local, o app usa `http://10.0.2.2:8080` por padrão. Em uma distribuição de teste ou produção, informe o endereço HTTPS da API.
