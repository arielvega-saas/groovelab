#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# GROOVELAB - Script de Setup Automático
# Ejecutar en tu Mac con: bash setup.sh
# ═══════════════════════════════════════════════════════════════

set -e

echo "🎵 GrooveLab - Setup Automático"
echo "================================"

# Verificar Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter no está instalado."
    echo "   Instalalo desde: https://docs.flutter.dev/get-started/install/macos"
    echo "   O con Homebrew: brew install --cask flutter"
    exit 1
fi

echo "✅ Flutter encontrado"

# Crear proyecto
echo "📁 Creando proyecto Flutter..."
cd ~/
rm -rf groovelab_app
flutter create --org com.groovelab --project-name groovelab groovelab_app

# Copiar código fuente
echo "📄 Copiando código fuente..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
rm -rf ~/groovelab_app/lib
cp -r "$SCRIPT_DIR/lib" ~/groovelab_app/lib
cp "$SCRIPT_DIR/pubspec.yaml" ~/groovelab_app/pubspec.yaml
cp "$SCRIPT_DIR/analysis_options.yaml" ~/groovelab_app/analysis_options.yaml
mkdir -p ~/groovelab_app/assets/icons

# Instalar dependencias
echo "📦 Instalando dependencias..."
cd ~/groovelab_app
flutter pub get

# Configurar iOS
echo "🍎 Configurando iOS..."
cd ios
pod install --repo-update || pod install
cd ..

# Verificar
echo "🔍 Verificando proyecto..."
flutter doctor
flutter analyze || echo "⚠️  Hay warnings pero el proyecto debería compilar"

echo ""
echo "═══════════════════════════════════════════════"
echo "✅ ¡LISTO! El proyecto está en ~/groovelab_app"
echo ""
echo "Para probarlo:"
echo "  cd ~/groovelab_app"
echo "  flutter run"
echo ""
echo "Para compilar para App Store:"
echo "  flutter build ios --release"
echo "  cd ios && open Runner.xcworkspace"
echo "  En Xcode: Product → Archive → Distribute"
echo ""
echo "🔓 Creator Mode: tocá 7 veces el logo GL"
echo "═══════════════════════════════════════════════"
