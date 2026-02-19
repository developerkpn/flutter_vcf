# flutter_vcf

Vehicle Control System - Flutter Mobile App

## Getting Started

### Prerequisites

- Flutter SDK (3.9.2+)
- Dart SDK (3.9.2+)
- Backend API running (Laravel)

### Running the App

#### 1. Configure Environment

Edit `.env` values (or keep defaults):

```bash
APP_ENV=dev
API_BASE_URL=
DEV_API_BASE_URL_ANDROID=http://10.0.2.2:8000/api/
DEV_API_BASE_URL=http://localhost:8000/api/
PROD_API_BASE_URL=https://your-server.com/api/
```

#### 2. Run

```bash
flutter run
```

For production mode, set:

```bash
APP_ENV=prod
```

### API Configuration

The app uses `.env` values loaded at startup (`flutter_dotenv`).

Supported variables:

- `APP_ENV`: `dev` or `prod`
- `API_BASE_URL`: hard override for all environments (highest priority)
- `DEV_API_BASE_URL_ANDROID`: dev URL for Android emulator
- `DEV_API_BASE_URL`: dev URL for iOS/macOS/etc
- `PROD_API_BASE_URL`: prod URL
- `USE_LOCAL_DEV`: optional legacy bool fallback

### Environment Variables

Unlike `--dart-define`, these are managed in `.env`.

```bash
# Development
APP_ENV=dev

# Full override (highest priority)
API_BASE_URL=https://staging.example.com/api/

# Production
APP_ENV=prod
```

### Other Commands

```bash
# Install dependencies
flutter pub get

# Generate API client + models (REQUIRED after model changes)
flutter pub run build_runner build --delete-conflicting-outputs

# Build APK
flutter build apk

# Build iOS
flutter build ios
```

### Troubleshooting

**Issue: App connects to production URL instead of local**
- Make sure `.env` has `APP_ENV=dev`
- Check logs for `[CONFIG] Resolved API_BASE_URL=...`

**Issue: Cannot connect to local API on Android**
- Android emulator uses `10.0.2.2` instead of `localhost`
- Make sure your backend is running and accessible

**Issue: Cannot connect to local API on iOS**
- Make sure your backend is running on `localhost:8000`
- Check firewall settings

## Project Structure

See `AGENTS.md` for detailed project structure and conventions.

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
