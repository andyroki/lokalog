# LokaLog Lawn-Care Scenario

This app is now a scenario prototype for lawn care professionals.

## Scenario
The user enters a list of client addresses. The app simulates GPS tracking and:

1. Logs worker location updates.
2. Cross-references each location to the nearest client address.
3. Detects when the worker remains at a property for at least 20 minutes.
4. Prompts the user to confirm that the job happened.
5. Auto-logs the job if there is no response within the prompt countdown.

## Validation Strategy To Reduce False Positives
The prototype uses layered checks before logging:

1. GPS accuracy gate: sample must be 30 meters or better.
2. Motion gate: speed must be below 1.2 m/s (not driving past).
3. Geofence gate: location must be within 80 meters of a matched address.
4. Dwell-time gate: worker must remain in the zone for at least 20 minutes.
5. Confirmation step: user confirms job, otherwise app auto-logs and marks it for review.

This combination helps avoid accidental logs from noisy GPS, short stops, or pass-by traffic.

## Run

```bash
flutter pub get
flutter run
```

To run on your connected phone:

```bash
flutter run -d ZY22L93QR9
flutter run -d R5GL234YAGT
```

## Release Build (PowerShell)

```powershell
$buildDate = Get-Date -Format 'yyyy-MM-dd'
$buildTime = Get-Date -Format 'HH:mm:ss'
flutter build apk --release --dart-define=BUILD_DATE=$buildDate --dart-define=BUILD_TIME=$buildTime
```

APK output:

`build/app/outputs/flutter-apk/app-release.apk`

Use this APK only for direct install/testing. Do not upload APK when publishing to Google Play if you are using an AAB.

## App Bundle (Play Store, PowerShell)

```powershell
$buildDate = Get-Date -Format 'yyyy-MM-dd'
$buildTime = Get-Date -Format 'HH:mm:ss'
flutter build appbundle --release --dart-define=BUILD_DATE=$buildDate --dart-define=BUILD_TIME=$buildTime
```

AAB output:

`build/app/outputs/bundle/release/app-release.aab`

Upload only the `.aab` file to Play Console. If Play reports version conflicts, increase the build number (for example `--build-number 4`).

Use this for release change build number/
flutter build appbundle --release --build-name 1.0.1 --build-number 20 