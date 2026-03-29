# GrooveLab — Guía Completa para Publicar en App Store con Claude Code

## RESUMEN

Esta guía te lleva paso a paso desde tener el código hasta tener la app
publicada en la App Store. Usamos **Claude Code** desde la terminal de tu Mac
para hacer todo el trabajo pesado.

---

## PASO 0 — REQUISITOS PREVIOS

### Instalar en tu Mac:

**1. Xcode** (obligatorio para compilar iOS)
```bash
# Abrir App Store de tu Mac → buscar "Xcode" → Instalar
# Pesa ~12GB, tarda un rato

# Después de instalar, abrir Terminal y correr:
sudo xcode-select --install
sudo xcodebuild -license accept
```

**2. Node.js** (necesario para Claude Code)
```bash
# Ir a https://nodejs.org → descargar LTS → instalar
# O si tenés Homebrew:
brew install node
```

**3. Claude Code**
```bash
npm install -g @anthropic-ai/claude-code
```

**4. Flutter** (el framework de la app)
```bash
# Ir a https://docs.flutter.dev/get-started/install/macos
# O con Homebrew:
brew install --cask flutter

# Verificar instalación:
flutter doctor
```

**5. CocoaPods** (dependencias de iOS)
```bash
sudo gem install cocoapods
```

**6. Cuenta Apple Developer**
- Ir a https://developer.apple.com/programs/enroll/
- Cuesta USD $99/año
- Necesitás tu Apple ID
- Tarda 24-48 horas en aprobarse
- SIN ESTO NO PODÉS PUBLICAR (pero podés desarrollar y probar gratis)

---

## PASO 1 — CREAR EL PROYECTO CON CLAUDE CODE

Abrí Terminal en tu Mac y ejecutá:

```bash
# Crear carpeta del proyecto
mkdir ~/GrooveLab
cd ~/GrooveLab

# Iniciar Claude Code
claude
```

Una vez dentro de Claude Code, copiá y pegá este prompt:

---

### PROMPT PARA CLAUDE CODE (copiar todo esto):

```
Creá un proyecto Flutter completo para una app llamada "GrooveLab" 
(subtítulo: "Metronome & Rhythm Trainer").

La app es un metrónomo profesional con drum machine, looper, 
entrenador rítmico y sistema de monetización.

REQUISITOS TÉCNICOS:
- Flutter con audio de baja latencia
- Usa el paquete flutter_soloud o audioplayers para el audio
- Arquitectura limpia con riverpod para state management
- Soporte iOS y Android

FUNCIONALIDADES PRINCIPALES:

1. METRÓNOMO:
   - Rango: 20-500 BPM
   - Rueda circular central de tempo (draggable)
   - Tap Tempo (últimos 6 taps, promedio)
   - Botones +/- 
   - Slider de tempo
   - Nombres musicales: Grave, Largo, Adagio, Andante, Moderato, Allegro, Vivace, Presto
   - Compases: 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 12/8
   - Subdivisiones: negra, corchea, tresillo, semicorchea
   - 6 sonidos de click: Madera, Digital, Hi-Hat, Clave, Cencerro, Beep
   - Acentos personalizables por beat
   - Control de Swing (0-100%)
   - Visualización de beats animada
   - Flash visual en downbeat

2. DRUM MACHINE:
   - Secuenciador de 16 pasos
   - 7 estilos: Rock, Pop, Funk, Blues, Jazz, Shuffle, Latin
   - Instrumentos: Kick, Snare, Hi-Hat, Ride
   - Muteo individual de instrumentos
   - Patrones editables

3. LOOPER:
   - Grabar audio del micrófono
   - Reproducción en loop
   - Overdub
   - Borrar loop
   - Visualización de forma de onda

4. MODO PRÁCTICA:
   - Aumento automático de BPM (configurable)
   - Entrenamiento por intervalos (compases con/sin click)
   - Silencio aleatorio (probabilidad configurable)

5. BIBLIOTECA:
   - Guardar presets de canciones (nombre, BPM, compás, estilo)
   - Cargar presets

6. ESTADÍSTICAS:
   - Tiempo total de práctica
   - Cantidad de sesiones
   - BPM actual

7. MULTI-IDIOMA:
   - Español, English, Português, Français, Deutsch, Italiano, 日本語
   - Selector en Settings

8. MONETIZACIÓN (Free/Pro):
   Plan Gratis: metrónomo básico, 3 compases, 2 estilos batería, 5 canciones
   Plan Pro ($4.99/mes o $39.99/año): todo desbloqueado
   - Usar in_app_purchase para iOS
   - Pantalla de upgrade con toggle mensual/anual

9. DISEÑO:
   - Tema oscuro estilo estudio musical
   - Colores: negro profundo, gris oscuro, acentos neon azul (#00d4ff), verde (#00ff88)
   - Fuentes: Outfit para UI, JetBrains Mono para números
   - Animaciones suaves a 60fps
   - Modo escenario (BPM gigante, alto contraste)

10. CONFIGURACIÓN iOS:
    - Bundle ID: com.tuempresa.groovelab (cambiar "tuempresa")
    - Versión: 1.0.0
    - Deployment target: iOS 15.0
    - Orientaciones: portrait
    - Permisos: micrófono (para looper)

Generá la estructura completa del proyecto con todos los archivos.
Asegurate de que compile sin errores con "flutter build ios".
```

---

## PASO 2 — COMPILAR Y PROBAR EN TU iPHONE

### Conectar tu iPhone:

```bash
# Conectá tu iPhone al Mac con el cable USB
# En el iPhone: Ajustes → Privacidad → Modo desarrollador → Activar
# Cuando conectás, dale "Confiar" en el iPhone

cd ~/GrooveLab

# Ver dispositivos conectados
flutter devices

# Correr la app en tu iPhone (GRATIS, sin cuenta developer)
flutter run
```

### Si querés usar Xcode directamente:

```bash
cd ~/GrooveLab/ios
open Runner.xcworkspace
```

En Xcode:
1. Seleccioná tu iPhone como destino arriba
2. En "Runner" → Signing & Capabilities → seleccioná tu Team (tu Apple ID personal)
3. Dale Play (▶) para correr en tu iPhone

**IMPORTANTE**: Con tu Apple ID personal (gratis) podés instalar la app
en TU iPhone para probar. La app se vence cada 7 días y hay que reinstalar.
Con la cuenta Developer de $99/año dura 1 año y podés publicar.

---

## PASO 3 — CONFIGURAR COMO CREADOR (USO GRATIS PARA VOS)

Pedile a Claude Code:

```
Agregá un sistema de "Creator Mode" a la app:
- Si el usuario escribe un código secreto en Settings (por ejemplo: tocar 
  7 veces el logo de GrooveLab), se activa modo creador
- Modo creador = Plan Pro activado permanentemente sin pagar
- Guardar este estado de forma persistente con shared_preferences
- No mostrar ningún indicador visible de que existe este modo
```

Así vos tenés Pro gratis y los demás usuarios ven el plan Free/Pro normal.

---

## PASO 4 — PREPARAR PARA APP STORE

### 4.1 Crear los assets necesarios

Pedile a Claude Code:

```
Generá todos los assets necesarios para publicar en App Store:

1. Ícono de la app (1024x1024) con el logo "GL" en gradiente azul-verde
   sobre fondo negro. Guardalo como assets/icon/icon.png
   Usá el paquete flutter_launcher_icons para generar todos los tamaños.

2. Splash screen con el logo centrado sobre fondo negro.
   Usá flutter_native_splash.

3. Generá screenshots de la app para App Store (6.5" y 5.5"):
   - Screenshot 1: Metrónomo principal
   - Screenshot 2: Drum Machine
   - Screenshot 3: Modo Práctica
   - Screenshot 4: Pantalla Pro
```

### 4.2 Configurar In-App Purchase

En https://appstoreconnect.apple.com:

1. Ir a "Mi Apps" → crear nueva app
2. En "Suscripciones" crear:
   - `groovelab_pro_monthly` — $4.99/mes
   - `groovelab_pro_yearly` — $39.99/año
3. Configurar grupo de suscripción

### 4.3 Build final

```bash
cd ~/GrooveLab

# Build de release para iOS
flutter build ios --release

# Abrir en Xcode para el archive final
cd ios
open Runner.xcworkspace
```

En Xcode:
1. Product → Archive
2. Esperar que compile
3. Distribute App → App Store Connect → Upload

---

## PASO 5 — SUBIR A APP STORE CONNECT

### 5.1 En https://appstoreconnect.apple.com:

1. **Mi Apps** → **+** → **Nueva App**
   - Plataforma: iOS
   - Nombre: GrooveLab - Metronome & Rhythm Trainer
   - Idioma principal: Español
   - Bundle ID: com.tuempresa.groovelab
   - SKU: groovelab001

2. **Información de la app**:
   - Categoría: Música
   - Subcategoría: Utilidades
   - Clasificación: 4+ (sin contenido objetable)

3. **Descripción** (usá esta):

```
🎵 GrooveLab - Metrónomo y Entrenador Rítmico

El metrónomo más completo para músicos profesionales y estudiantes.

METRÓNOMO PROFESIONAL
• Rango de 20 a 500 BPM con precisión extrema
• Rueda de tempo intuitiva estilo hardware
• Tap Tempo inteligente
• 8 compases: 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 12/8
• 6 sonidos de click profesionales
• Subdivisiones: negra, corchea, tresillo, semicorchea
• Control de Swing para sensación humana

DRUM MACHINE
• 7 estilos: Rock, Pop, Funk, Blues, Jazz, Shuffle, Latin
• Secuenciador de 16 pasos editable
• Muteo individual de instrumentos

LOOPER
• Graba loops desde tu micrófono
• Overdub para capas adicionales
• Sincronización con metrónomo

ENTRENADOR RÍTMICO
• Aumento automático de BPM
• Entrenamiento por intervalos
• Silencios aleatorios para mejorar tu tempo interno

BIBLIOTECA
• Guarda presets de canciones
• Organiza tu práctica

ESTADÍSTICAS
• Registra tu tiempo de práctica
• Seguimiento de sesiones

MODO ESCENARIO
• BPM gigante para tocar en vivo
• Alto contraste

Disponible en 7 idiomas: Español, English, Português, Français, 
Deutsch, Italiano, 日本語

Descargá GrooveLab y llevá tu práctica musical al siguiente nivel.
```

4. **Keywords**: metronome, metronomo, drum machine, rhythm, ritmo, 
   practice, practica, bpm, tempo, musica, guitar, guitarra, bass, bajo

5. **Screenshots**: subir las capturas generadas

6. **Precio**: Gratis (con compras in-app)

7. **Privacidad**: 
   - URL de política de privacidad (necesitás crear una, puede ser 
     una página simple en GitHub Pages)

### 5.2 Enviar a revisión

1. Seleccionar el build que subiste desde Xcode
2. Completar todos los campos obligatorios
3. Click en **"Enviar para revisión"**
4. Apple tarda entre 1-7 días en revisar

---

## PASO 6 — PUBLICAR EN GOOGLE PLAY (opcional)

```bash
# Compilar para Android
flutter build appbundle --release

# El archivo .aab se genera en:
# build/app/outputs/bundle/release/app-release.aab
```

1. Ir a https://play.google.com/console
2. Crear cuenta de developer ($25 único)
3. Crear app → subir el .aab
4. Completar la ficha de la tienda (similar a App Store)

---

## RESUMEN DE COSTOS

| Concepto                  | Costo         |
|---------------------------|---------------|
| Cuenta Apple Developer    | $99/año       |
| Cuenta Google Play        | $25 (único)   |
| Flutter                   | Gratis        |
| Claude Code               | Según tu plan |
| Hosting política privacidad | Gratis (GitHub Pages) |
| **TOTAL para empezar**    | **~$124**     |

---

## COMANDOS RÁPIDOS DE REFERENCIA

```bash
# Iniciar Claude Code en el proyecto
cd ~/GrooveLab && claude

# Correr en iPhone conectado
flutter run

# Correr en simulador iOS
flutter run -d "iPhone 15"

# Build de release iOS
flutter build ios --release

# Build de release Android
flutter build appbundle --release

# Verificar estado del proyecto
flutter doctor
flutter analyze

# Limpiar y reconstruir
flutter clean && flutter pub get

# Abrir en Xcode
cd ios && open Runner.xcworkspace
```

---

## TROUBLESHOOTING

**"No devices found"**: Asegurate de que el iPhone está conectado 
y desbloqueado, y que le diste "Confiar" al Mac.

**"Signing requires a development team"**: En Xcode, seleccioná tu 
Apple ID como Team en Runner → Signing & Capabilities.

**"Module not found"**: Corré `cd ios && pod install && cd ..`

**"Flutter doctor issues"**: Seguí las instrucciones que muestra 
`flutter doctor` para resolver cada issue.

**La app se vence en el iPhone**: Con Apple ID gratis dura 7 días. 
Con cuenta Developer ($99) dura 1 año. Solución: reinstalar o pagar 
la cuenta developer.

---

## SIGUIENTE PASO

Abrí Terminal en tu Mac y empezá:

```bash
mkdir ~/GrooveLab
cd ~/GrooveLab
claude
```

Y pegá el prompt del PASO 1. Claude Code va a generar todo el proyecto.
¡Buena suerte! 🎵
