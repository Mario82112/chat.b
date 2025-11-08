# 📱 Bluetooth Chat App

Aplicación de chat Bluetooth sin conexión a Internet desarrollada en Flutter.

## ✨ Características

- 💬 Chat bidireccional por Bluetooth
- 😀 Emojis y stickers
- 🔍 Descubrimiento automático de dispositivos
- 🔄 Reconexión automática
- 📱 Compatible con Android 5.0+

## 🚀 Descargar APK

Los APKs compilados están disponibles en la sección **Actions** de este repositorio.

### Pasos para descargar:

1. Ve a la pestaña **Actions** (arriba)
2. Click en el último workflow exitoso (✅ verde)
3. Baja hasta **Artifacts**
4. Descarga el APK para tu dispositivo:
   - **app-arm64-v8a-release** (recomendado para la mayoría de celulares modernos)
   - **app-armeabi-v7a-release** (para celulares antiguos)
   - **app-x86_64-release** (para emuladores)

## 📦 Compilar Localmente

### Requisitos:
- Flutter SDK 3.0+
- Java JDK 8+
- Android SDK

### Comandos:
```bash
# Instalar dependencias
flutter pub get

# Compilar APK
flutter build apk --release --split-per-abi
```

## 🔐 Permisos

La app requiere los siguientes permisos:
- Bluetooth
- Ubicación (requerido por Android para escaneo Bluetooth)

## 📄 Licencia

Este proyecto es de código abierto.
