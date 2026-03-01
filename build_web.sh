#!/bin/bash
# Flutter 웹 빌드 + 캐시 버스팅 스크립트

echo "[1/2] Flutter 웹 빌드 중..."
flutter build web --pwa-strategy=none

if [ $? -ne 0 ]; then
    echo "빌드 실패!"
    exit 1
fi

echo "[2/2] main.dart.js 캐시 버스팅 적용 중..."
timestamp=$(date +%s)
sed -i "s/main\.dart\.js/main.dart.js?v=$timestamp/g" build/web/flutter_bootstrap.js
echo "완료! (v=$timestamp)"
echo "build/web/ 폴더를 서버에 배포하세요."
