# 📱 Bluetooth Chat - Compilación APK

## 🚀 Instrucciones para Generar APK

### Requisitos Previos:
1. **Flutter SDK** instalado
2. **Android Studio** o **Android SDK** configurado
3. **Java JDK 8+** instalado

### 📋 Pasos para Compilar:

#### 1. Preparar el Entorno
```bash
# Verificar instalación de Flutter
flutter doctor

# Si hay problemas, seguir las instrucciones de flutter doctor
```

#### 2. Instalar Dependencias
```bash
# En la carpeta del proyecto
flutter pub get
```

#### 3. Compilar APK
```bash
# APK de depuración (más rápido)
flutter build apk --debug

# APK de release (optimizado)
flutter build apk --release

# APK dividido por arquitectura (más pequeño)
flutter build apk --split-per-abi
```

### 📁 Ubicación del APK Generado:
```
build/app/outputs/flutter-apk/
├── app-debug.apk          # Versión de depuración
├── app-release.apk        # Versión optimizada
├── app-arm64-v8a-release.apk    # Solo ARM 64-bit
├── app-armeabi-v7a-release.apk  # Solo ARM 32-bit
└── app-x86_64-release.apk       # Solo x86 64-bit
```

### 🔧 Configuración Actual:
- **Nombre de la app**: Bluetooth Chat
- **Package ID**: com.example.bluetooth_chat
- **Versión**: 1.0.0+1
- **SDK mínimo**: Android 21 (Android 5.0)
- **SDK objetivo**: Último disponible

### 📱 Permisos Incluidos:
- ✅ BLUETOOTH
- ✅ BLUETOOTH_ADMIN
- ✅ ACCESS_COARSE_LOCATION
- ✅ ACCESS_FINE_LOCATION
- ✅ BLUETOOTH_SCAN (Android 12+)
- ✅ BLUETOOTH_CONNECT (Android 12+)
- ✅ BLUETOOTH_ADVERTISE (Android 12+)

### 🛠️ Solución de Problemas:

#### Error: Flutter SDK no encontrado
```bash
# Configurar variable de entorno
export PATH="$PATH:/ruta/a/flutter/bin"
```

#### Error: Android SDK no encontrado
```bash
# Configurar en local.properties
echo "sdk.dir=/ruta/a/Android/Sdk" >> android/local.properties
```

#### Error de permisos en Android 12+
- Los permisos están configurados correctamente
- La app solicitará permisos en tiempo de ejecución

### 📦 Archivos Incluidos en este ZIP:
```
bluetooth_chat_apk/
├── lib/
│   └── main.dart                    # Código principal
├── android/
│   ├── app/
│   │   ├── build.gradle            # Configuración de la app
│   │   └── src/main/
│   │       └── AndroidManifest.xml # Permisos y configuración
│   ├── build.gradle                # Configuración del proyecto
│   ├── gradle.properties           # Propiedades de Gradle
│   └── settings.gradle             # Configuración de módulos
├── pubspec.yaml                    # Dependencias de Flutter
└── README_APK.md                   # Este archivo
```

### 🎯 Comandos Rápidos:
```bash
# Compilar y instalar en dispositivo conectado
flutter install

# Compilar APK de release optimizado
flutter build apk --release --shrink

# Ver dispositivos conectados
flutter devices

# Ejecutar en dispositivo específico
flutter run -d <device_id>
```

### ✅ Verificación Final:
1. APK generado en `build/app/outputs/flutter-apk/`
2. Tamaño aproximado: 15-25 MB
3. Compatible con Android 5.0+
4. Todas las funcionalidades incluidas:
   - Chat bidireccional
   - Emojis y stickers
   - Descubrimiento automático
   - Conexión Bluetooth robusta

### 📞 Soporte:
Si tienes problemas, verifica:
1. `flutter doctor` sin errores
2. Dispositivo Android en modo desarrollador
3. Depuración USB habilitada
4. Permisos de ubicación concedidos (necesarios para Bluetooth)
