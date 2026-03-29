# INSTRUCCIONES PARA CLAUDE CODE

## Este proyecto ya tiene todo el código fuente. Solo necesitás ejecutar estos comandos:

### PASO 1: Crear proyecto Flutter e inyectar el código
```bash
cd ~/
flutter create --org com.groovelab --project-name groovelab groovelab_app
cp -r groovelab_source/lib/* groovelab_app/lib/
cp groovelab_source/pubspec.yaml groovelab_app/pubspec.yaml
cp groovelab_source/analysis_options.yaml groovelab_app/analysis_options.yaml
mkdir -p groovelab_app/assets/icons
cd groovelab_app
```

### PASO 2: Instalar dependencias
```bash
flutter pub get
```

### PASO 3: Configurar iOS
```bash
cd ios
pod install
cd ..
```

### PASO 4: Probar en simulador
```bash
flutter run
```

### PASO 5: Probar en iPhone (conectar con cable USB)
```bash
flutter run -d <tu_device_id>
# Para ver devices: flutter devices
```

### PASO 6: Build de release
```bash
flutter build ios --release
cd ios
open Runner.xcworkspace
# En Xcode: Product → Archive → Distribute
```

## Si hay errores de compilación, pedile a Claude Code:
"Arreglá los errores de compilación del proyecto Flutter en esta carpeta"

## Para agregar el ícono:
Generá una imagen PNG de 1024x1024 con las letras "GL" en gradiente
azul-verde sobre fondo negro y guardala en assets/icons/icon.png,
después corré: flutter pub run flutter_launcher_icons
