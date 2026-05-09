# Релиз через GitHub

Проект распространяется только через GitHub Releases. Основной артефакт релиза - подписанный Android APK.

## Секреты GitHub Actions

В настройках репозитория `nikosters/question-trainer` добавьте secrets:

- `ANDROID_KEYSTORE_BASE64` - release keystore в base64
- `ANDROID_KEYSTORE_PASSWORD` - пароль keystore
- `ANDROID_KEY_ALIAS` - alias ключа
- `ANDROID_KEY_PASSWORD` - пароль ключа

Keystore и пароли нельзя коммитить в репозиторий.

## Создание keystore

Пример команды:

```bash
keytool -genkeypair \
  -v \
  -keystore android/release-keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias question-trainer
```

Base64 для GitHub Secret:

```bash
base64 -w 0 android/release-keystore.jks
```

## Выпуск версии

1. Обновите `version` в `pubspec.yaml`, если нужно.
2. Обновите `CHANGELOG.md`.
3. Убедитесь, что проверки проходят:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

4. Создайте и отправьте тег:

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions соберет APK и прикрепит его к GitHub Release:

```text
question-trainer-v1.0.0-android-universal.apk
```

## Nightly-релизы

Nightly-релизы публикуются из ветки `nightly` workflow `Nightly Android APK`.
Каждый push в `nightly` запускает проверки, собирает подписанный release APK и
обновляет один moving pre-release с тегом `nightly`.

Nightly использует те же Android signing secrets, что и стабильные релизы.
Артефакт nightly-релиза:

```text
question-trainer-nightly-android-universal.apk
```

## Ручной запуск

Workflow `Release Android APK` можно запустить вручную через GitHub Actions. Для ручного запуска нужен ref, который указывает на нужный коммит или тег.
