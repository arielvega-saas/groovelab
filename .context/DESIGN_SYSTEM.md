# GrooveLab — Design System

## Colores (definidos en lib/core/theme.dart)

### Fondos
```
bgDeepest   #0A0A0A    Fondo mas oscuro (body)
bgDark      #121212    Fondo principal
bgPanel     #212121    Paneles y cards
bgInset     #1A1A1A    Areas hundidas
bgElevated  #252525    Elementos elevados
bgInput     #2C2C2E    Campos de input
```

### Acentos
```
accent      #00E5FF    Cyan — color principal de la app
accent2     #00FF11    Verde — confirmacion/activo
warm        #FF9500    Naranja — alertas, click
danger      #FF3B30    Rojo — peligro, grabacion
warning     #FF9F0A    Ambar — advertencias
gold        #FFD700    Dorado — premium
```

### Texto
```
textPrimary    rgba(255,255,255,0.87)   Texto principal
textSecondary  #8E8E93                   Texto secundario
textMuted      #636366                   Texto apagado
```

### Bordes
```
border       #2A2A2E    Borde estandar
borderLight  #3A3A3E    Borde claro
```

### Colores por instrumento (para mixer/channels)
```
click     #FF9500   Orange
drums     #00E5FF   Cyan
bass      #4FC3F7   Light Blue
guitar    #FF3B30   Red
keys      #FF9F0A   Amber
vocals    #FF6B35   Deep Orange
synth     #A855F7   Purple
pad       #8B5CF6   Violet
guide     #22D3EE   Cyan alt
loop      #F472B6   Pink
coro      #34D399   Green
master    #FFFFFF   White
```

### Colores de bateria
```
kick      #FF6B35
snare     #4FC3F7
hihat     #00E5FF
ride      #00FF11
clap      #E040FB
bass      #FFB020
```

## Tipografia

### Familias (definidas en lib/core/app_fonts.dart)
```
Outfit           UI general (400 regular, 700 bold)
JetBrains Mono   Datos numericos, tiempos, BPM, codigo
Space Mono       Alternativa monospace
```

### Uso
```dart
AppFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)
AppFonts.jetBrainsMono(fontSize: 11, color: AppColors.accent)
AppFonts.spaceMono(fontSize: 10, color: AppColors.textMuted)
```

## Efectos

### Neumorfismo (para faders, botones, controles)
```dart
// Elevado
AppColors.neumorphicRaised()
// box-shadow: 5px 5px 10px #181818, -5px -5px 10px #2a2a2a

// Hundido
AppColors.neumorphicInset()
// box-shadow: inset 2px 2px 4px #181818, inset -2px -2px 4px #2a2a2a

// LED glow
AppColors.ledGlow(color)
// box-shadow: 0 0 8px rgba(color, 0.6)
```

### CSS equivalente (para HTMLs)
```css
/* Fondos */
--bg-deepest: #0A0A0C;
--bg-dark: #111114;
--bg-panel: #1A1A1F;
--bg-inset: #0e0e12;
--bg-elevated: #222228;

/* Acentos */
--accent: #00E5FF;
--accent2: #00FF11;
--warm: #FF9500;
--danger: #FF3B30;

/* Texto */
--txt: #E8E8EC;
--txt2: #888892;
--txt3: #55555f;

/* Fader track gradient */
--fader-track: linear-gradient(180deg, #0c0c10 0%, #18181e 50%, #0c0c10 100%);

/* Neumorphic raised */
box-shadow: 5px 5px 10px #181818, -5px -5px 10px #2a2a2a;

/* Neumorphic inset */
box-shadow: inset 2px 2px 4px #181818, inset -2px -2px 4px #2a2a2a;

/* LED glow */
box-shadow: 0 0 8px rgba(color, 0.6);
```

## Spacing y Sizing (AppSpacing, AppRadius, AppSizes)
```
xs: 4     sm: 8     md: 16    lg: 24    xl: 32
radiusSm: 6   radiusMd: 10   radiusLg: 16   radiusFull: 999
navBarHeight: 56
```

## Estetica general
- Inspirada en Logic Pro, MainStage, consolas de audio profesionales
- Fondos oscuros con degradados sutiles
- Controles neumorticos (faders, knobs)
- VU meters estilo LED (12 segmentos: verde -> amarillo -> rojo)
- Tipografia mono para datos numericos
- Sombras internas para areas hundidas
- Glows cyan para elementos activos
- Texture de ruido sutil sobre fondo (opacity 3%)
