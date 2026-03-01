# Flutter 웹 빌드 + 캐시 버스팅 스크립트
Write-Host "[1/2] Flutter 웹 빌드 중..." -ForegroundColor Cyan
flutter build web --pwa-strategy=none

if ($LASTEXITCODE -ne 0) {
    Write-Host "빌드 실패!" -ForegroundColor Red
    exit 1
}

Write-Host "[2/2] main.dart.js 캐시 버스팅 적용 중..." -ForegroundColor Cyan
$timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
(Get-Content build/web/flutter_bootstrap.js) -replace 'main\.dart\.js', "main.dart.js?v=$timestamp" | Set-Content build/web/flutter_bootstrap.js
Write-Host "완료! (v=$timestamp)" -ForegroundColor Green
Write-Host "build/web/ 폴더를 서버에 배포하세요." -ForegroundColor Yellow
