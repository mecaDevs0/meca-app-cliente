#!/bin/bash
set -e

echo "[INFO] Entrando na pasta do projeto: /meca/meca-app-cliente-main"
cd /meca/meca-app-cliente-main

echo "[INFO] Limpando builds anteriores..."
flutter clean

echo "[INFO] Verificando dependências locais..."
ls -la /meca/mega_payment
ls -la /meca/mega_commons
ls -la /meca/mega_features
ls -la /meca/mega_commons_dependencies

echo "[INFO] Configurando Flutter..."
flutter config --no-analytics
flutter config --enable-linux-desktop

echo "[INFO] Rodando flutter pub get..."
flutter pub get

echo "[INFO] Rodando build_runner (se necessário)..."
flutter pub run build_runner build --delete-conflicting-outputs || true

echo "[INFO] Iniciando build do APK..."
flutter build apk \
  --release \
  --no-tree-shake-icons \
  --no-pub \
  --dart-define=Env=prod

if [ -f build/app/outputs/flutter-apk/app-release.apk ]; then
  echo "[INFO] APK gerado com sucesso, copiando para /output"
  cp build/app/outputs/flutter-apk/app-release.apk /output/app-release.apk
  echo "[INFO] APK disponível em /output/app-release.apk"
else
  echo "[ERRO] APK não foi gerado! Verifique os logs acima."
  exit 1
fi

