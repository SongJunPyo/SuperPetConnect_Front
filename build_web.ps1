# Flutter 웹 빌드 + 캐시 버스팅 스크립트
#
# FCM Web Push 활성화에 VAPID 공개키 필수 (--dart-define으로 주입).
# VAPID 공개키는 의도적으로 client에 노출되는 값이라 commit 가능 (private key는 FCM 서버에만).
$VapidKey = "BCaX2N50yOe7GS8ua6YAVxH70pUJW4qVzzsyRYNCe5sqGJxUSth-7xE8XhJC9MsvWxwpOjicUEdypSPiABwMOhc"

Write-Host "[1/2] Flutter 웹 빌드 중..." -ForegroundColor Cyan
flutter build web --release --pwa-strategy=none --dart-define=FCM_VAPID_KEY=$VapidKey

if ($LASTEXITCODE -ne 0) {
    Write-Host "빌드 실패!" -ForegroundColor Red
    exit 1
}

Write-Host "[2/2] main.dart.js 캐시 버스팅 적용 중..." -ForegroundColor Cyan
$timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
(Get-Content build/web/flutter_bootstrap.js) -replace 'main\.dart\.js', "main.dart.js?v=$timestamp" | Set-Content build/web/flutter_bootstrap.js
Write-Host "완료! (v=$timestamp)" -ForegroundColor Green
Write-Host "build/web/ 폴더를 서버에 배포하세요." -ForegroundColor Yellow
