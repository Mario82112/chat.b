import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

// UUID único para identificar nuestra aplicación de chat Bluetooth
const String APP_UUID = '00001101-0000-1000-8000-00805F9B34FB';
const String APP_NAME = 'BluetoothChat';

void main() {
  runApp(const BluetoothChatApp());
}

class BluetoothChatApp extends StatelessWidget {
  const BluetoothChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "¡Hola! ¿Cómo estás?",
      isMe: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    ChatMessage(
      text: "¡Hola! Todo bien, ¿y tú?",
      isMe: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
    ),
    ChatMessage(
      text: "Genial, probando este chat Bluetooth",
      isMe: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
  ];

  // Variables de conexión Bluetooth
  BluetoothConnection? _bluetoothConnection;
  StreamSubscription<Uint8List>? _dataSubscription;
  bool _isConnected = false;
  String? _connectedDeviceName;
  
  // Variables para modo servidor
  BluetoothConnection? _serverConnection;
  StreamSubscription<BluetoothConnection>? _serverSubscription;
  bool _isServerRunning = false;
  
  // Variables para emojis y stickers
  bool _showEmojiPanel = false;

  @override
  void initState() {
    super.initState();
    _startBluetoothServer();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      String messageText = _messageController.text.trim();
      _sendMessageWithType(messageText, MessageType.text);
      _messageController.clear();
    }
  }

  void _sendEmoji(String emoji) {
    _sendMessageWithType(emoji, MessageType.emoji);
  }

  void _sendSticker(String sticker) {
    _sendMessageWithType(sticker, MessageType.sticker);
  }

  void _sendMessageWithType(String content, MessageType type) {
    // Agregar mensaje a la UI
    setState(() {
      _messages.add(ChatMessage(
        text: content,
        isMe: true,
        timestamp: DateTime.now(),
        type: type,
      ));
    });
    
    // Enviar mensaje vía Bluetooth si hay conexión
    if (_isConnected && _bluetoothConnection != null) {
      String messageToSend = "${type.name}:$content";
      _sendBluetoothMessage(messageToSend);
    }
  }

  Future<void> _sendBluetoothMessage(String message) async {
    try {
      if (_bluetoothConnection == null || !_isConnected) {
        _showSnackBar('No hay conexión activa');
        return;
      }
      
      // Convertir string a bytes UTF-8
      List<int> bytes = utf8.encode(message + '\n');
      
      // Enviar bytes a través de la conexión
      _bluetoothConnection!.output.add(Uint8List.fromList(bytes));
      await _bluetoothConnection!.output.allSent;
      
      print('Mensaje enviado vía Bluetooth: $message');
    } catch (exception) {
      print('Error al enviar mensaje Bluetooth: $exception');
      _showSnackBar('Error al enviar mensaje. Verifica la conexión.');
      
      // Si hay error de envío, verificar si la conexión se perdió
      _handleConnectionLost();
    }
  }

  Future<void> connectToDevice(String address, String deviceName) async {
    int maxRetries = 3;
    int currentRetry = 0;
    
    while (currentRetry < maxRetries) {
      try {
        // Mostrar indicador de conexión
        String retryText = currentRetry > 0 ? ' (Intento ${currentRetry + 1}/$maxRetries)' : '';
        _showSnackBar('Conectando a $deviceName$retryText...');
        
        // Establecer conexión usando el UUID de la app
        BluetoothConnection connection = await BluetoothConnection.toAddress(address)
            .timeout(const Duration(seconds: 15));
        
        setState(() {
          _bluetoothConnection = connection;
          _isConnected = true;
          _connectedDeviceName = deviceName;
        });
        
        // Comenzar a escuchar mensajes entrantes
        _listenForIncomingData();
        
        _showSnackBar('¡Conectado a $deviceName!');
        print('Conectado exitosamente a $address');
        return; // Salir del bucle si la conexión es exitosa
        
      } catch (exception) {
        currentRetry++;
        print('Error de conexión (intento $currentRetry): $exception');
        
        if (currentRetry >= maxRetries) {
          _showSnackBar('No se pudo conectar a $deviceName. Asegúrate de que tenga la app abierta.');
          setState(() {
            _isConnected = false;
            _connectedDeviceName = null;
          });
        } else {
          // Esperar antes del siguiente intento
          await Future.delayed(Duration(seconds: currentRetry * 2));
        }
      }
    }
  }

  void _listenForIncomingData() {
    _dataSubscription = _bluetoothConnection!.input!.listen(
      (Uint8List data) {
        // Convertir bytes a string
        String receivedMessage = utf8.decode(data).trim();
        
        if (receivedMessage.isNotEmpty) {
          print('Mensaje recibido: $receivedMessage');
          
          // Parsear tipo de mensaje
          MessageType messageType = MessageType.text;
          String messageContent = receivedMessage;
          
          if (receivedMessage.contains(':')) {
            List<String> parts = receivedMessage.split(':');
            if (parts.length >= 2) {
              String typeString = parts[0];
              messageContent = parts.sublist(1).join(':');
              
              switch (typeString) {
                case 'emoji':
                  messageType = MessageType.emoji;
                  break;
                case 'sticker':
                  messageType = MessageType.sticker;
                  break;
                default:
                  messageType = MessageType.text;
                  messageContent = receivedMessage;
              }
            }
          }
          
          // Agregar mensaje recibido a la UI
          setState(() {
            _messages.add(ChatMessage(
              text: messageContent,
              isMe: false,
              timestamp: DateTime.now(),
              type: messageType,
            ));
          });
        }
      },
      onError: (error) {
        print('Error al recibir datos: $error');
        _showSnackBar('Error de comunicación: $error');
      },
      onDone: () {
        print('Conexión cerrada por el otro dispositivo');
        _handleConnectionLost();
      }
    );
  }

  void _disconnectDevice() {
    _dataSubscription?.cancel();
    _bluetoothConnection?.dispose();
    
    setState(() {
      _bluetoothConnection = null;
      _isConnected = false;
      _connectedDeviceName = null;
    });
    
    _showSnackBar('Desconectado del dispositivo');
  }

  void _handleConnectionLost() {
    setState(() {
      _isConnected = false;
      _connectedDeviceName = null;
    });
    
    _showSnackBar('Conexión perdida. Toca el ícono de Bluetooth para reconectar.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showDeviceDiscovery(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeviceDiscoveryScreen(
          onDeviceSelected: connectToDevice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bluetooth Chat'),
            if (_isConnected && _connectedDeviceName != null)
              Text(
                'Conectado: $_connectedDeviceName',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: _disconnectDevice,
              tooltip: 'Desconectar',
            )
          else
            IconButton(
              icon: const Icon(Icons.bluetooth_searching),
              onPressed: () => _showDeviceDiscovery(context),
              tooltip: 'Buscar dispositivos',
            ),
        ],
      ),
      body: Column(
        children: [
          // Indicador de estado de conexión
          if (_isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                border: Border(
                  bottom: BorderSide(color: Colors.green.shade300),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.bluetooth_connected, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Conectado a $_connectedDeviceName',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'En línea',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          // Lista de mensajes
          Expanded(
            child: _messages.isEmpty && !_isConnected
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bluetooth_searching,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chat Bluetooth',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Conecta a un dispositivo para empezar a chatear',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showDeviceDiscovery(context),
                        icon: const Icon(Icons.bluetooth_searching),
                        label: const Text('Buscar Dispositivos'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];
                    return MessageBubble(message: message);
                  },
                ),
          ),
          // Campo de entrada de mensaje
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _isConnected ? () {
                        setState(() {
                          _showEmojiPanel = !_showEmojiPanel;
                        });
                      } : null,
                      icon: Icon(_showEmojiPanel ? Icons.keyboard : Icons.emoji_emotions),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: _isConnected,
                        decoration: InputDecoration(
                          hintText: _isConnected 
                            ? 'Escribe un mensaje...' 
                            : 'Conecta a un dispositivo para chatear',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    IconButton(
                      onPressed: _isConnected ? _sendMessage : null,
                      icon: const Icon(Icons.send),
                      style: IconButton.styleFrom(
                        backgroundColor: _isConnected 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        foregroundColor: _isConnected 
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                if (_showEmojiPanel) _buildEmojiPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPanel() {
    final emojis = ['😀', '😂', '🥰', '😍', '🤔', '👍', '👎', '❤️', '🔥', '💯', '🎉', '😎'];
    final stickers = ['🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐸'];
    
    return Container(
      height: 200,
      padding: const EdgeInsets.all(8),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Emojis'),
                Tab(text: 'Stickers'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Panel de emojis
                  GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      childAspectRatio: 1,
                    ),
                    itemCount: emojis.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          _sendEmoji(emojis[index]);
                          setState(() {
                            _showEmojiPanel = false;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                          ),
                          child: Center(
                            child: Text(
                              emojis[index],
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Panel de stickers
                  GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 1,
                    ),
                    itemCount: stickers.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          _sendSticker(stickers[index]);
                          setState(() {
                            _showEmojiPanel = false;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              stickers[index],
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _dataSubscription?.cancel();
    _bluetoothConnection?.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final MessageType type;

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.type = MessageType.text,
  });
}

enum MessageType {
  text,
  emoji,
  sticker,
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.person, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: message.isMe
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(18.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMessageContent(context),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: message.isMe
                          ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                          : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.type) {
      case MessageType.emoji:
        return Text(
          message.text,
          style: const TextStyle(fontSize: 32),
        );
      case MessageType.sticker:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.text,
            style: const TextStyle(fontSize: 48),
          ),
        );
      case MessageType.text:
      default:
        return Text(
          message.text,
          style: TextStyle(
            color: message.isMe
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
    }
  }
}

class DeviceDiscoveryScreen extends StatefulWidget {
  final Function(String address, String deviceName) onDeviceSelected;
  
  const DeviceDiscoveryScreen({
    super.key,
    required this.onDeviceSelected,
  });

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen> {
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  List<BluetoothDevice> _bondedDevices = [];
  List<BluetoothDiscoveryResult> _discoveredDevices = [];
  bool _isDiscovering = false;
  bool _bluetoothEnabled = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    // Verificar estado del Bluetooth
    BluetoothState state = await _bluetooth.state;
    setState(() {
      _bluetoothEnabled = state == BluetoothState.STATE_ON;
    });

    if (_bluetoothEnabled) {
      await _requestPermissions();
      await _getBondedDevices();
      _startAutoRefresh();
    }
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = statuses.values.every(
      (status) => status == PermissionStatus.granted
    );

    if (!allGranted) {
      _showSnackBar('Algunos permisos son necesarios para usar Bluetooth');
    }
  }

  Future<void> _getBondedDevices() async {
    try {
      List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
      setState(() {
        _bondedDevices = devices;
      });
    } catch (e) {
      _showSnackBar('Error al obtener dispositivos emparejados: $e');
    }
  }

  Future<void> _startDiscovery() async {
    if (!_bluetoothEnabled) {
      bool? enabled = await _bluetooth.requestEnable();
      if (enabled != true) {
        _showSnackBar('Bluetooth debe estar habilitado');
        return;
      }
      setState(() {
        _bluetoothEnabled = true;
      });
    }

    setState(() {
      _isDiscovering = true;
      _discoveredDevices.clear();
    });

    try {
      _bluetooth.startDiscovery().listen((result) {
        setState(() {
          // Evitar duplicados
          bool exists = _discoveredDevices.any(
            (device) => device.device.address == result.device.address
          );
          if (!exists) {
            _discoveredDevices.add(result);
          }
        });
      }).onDone(() {
        setState(() {
          _isDiscovering = false;
        });
      });
    } catch (e) {
      setState(() {
        _isDiscovering = false;
      });
      _showSnackBar('Error al buscar dispositivos: $e');
    }
  }

  Future<void> _stopDiscovery() async {
    await _bluetooth.cancelDiscovery();
    setState(() {
      _isDiscovering = false;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Dispositivos'),
        centerTitle: true,
        actions: [
          if (_bluetoothEnabled)
            IconButton(
              onPressed: _isDiscovering ? _stopDiscovery : _startDiscovery,
              icon: Icon(_isDiscovering ? Icons.stop : Icons.refresh),
            ),
        ],
      ),
      body: _bluetoothEnabled ? _buildDeviceList() : _buildBluetoothDisabled(),
    );
  }

  Widget _buildBluetoothDisabled() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 24),
          Text(
            'Bluetooth Deshabilitado',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Habilita Bluetooth para buscar dispositivos',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              bool? enabled = await _bluetooth.requestEnable();
              if (enabled == true) {
                setState(() {
                  _bluetoothEnabled = true;
                });
                await _getBondedDevices();
                _startAutoRefresh();
              }
            },
            icon: const Icon(Icons.bluetooth),
            label: const Text('Habilitar Bluetooth'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    List<Widget> allDevices = [];
    
    // Agregar dispositivos emparejados
    if (_bondedDevices.isNotEmpty) {
      allDevices.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Dispositivos Emparejados',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      
      for (BluetoothDevice device in _bondedDevices) {
        allDevices.add(_buildDeviceCard(
          name: device.name ?? 'Dispositivo desconocido',
          address: device.address,
          icon: Icons.bluetooth_connected,
          iconColor: Colors.blue,
          isConnected: true,
          onTap: () {
            Navigator.pop(context);
            widget.onDeviceSelected(
              device.address,
              device.name ?? 'Dispositivo desconocido',
            );
          },
        ));
      }
    }
    
    // Agregar dispositivos descubiertos
    if (_discoveredDevices.isNotEmpty) {
      allDevices.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Dispositivos Disponibles',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      
      for (BluetoothDiscoveryResult result in _discoveredDevices) {
        allDevices.add(_buildDeviceCard(
          name: result.device.name ?? 'Dispositivo desconocido',
          address: result.device.address,
          rssi: result.rssi,
          icon: Icons.bluetooth,
          iconColor: Colors.green,
          isConnected: false,
          onTap: () {
            Navigator.pop(context);
            widget.onDeviceSelected(
              result.device.address,
              result.device.name ?? 'Dispositivo desconocido',
            );
          },
        ));
      }
    }
    
    // Si no hay dispositivos
    if (allDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isDiscovering) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Buscando dispositivos...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ] else ...[
              Icon(
                Icons.bluetooth_searching,
                size: 80,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 24),
              Text(
                'No hay dispositivos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Toca el ícono de actualizar para buscar',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      );
    }
    
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: allDevices,
    );
  }

  Widget _buildDeviceCard({
    required String name,
    required String address,
    required IconData icon,
    required Color iconColor,
    required bool isConnected,
    required VoidCallback onTap,
    int? rssi,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                address,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
              ),
              if (rssi != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Señal: ${rssi}dBm',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          trailing: Icon(
            isConnected ? Icons.link : Icons.add_link,
            color: iconColor,
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isDiscovering && _bluetoothEnabled) {
        _startDiscovery();
      }
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    _stopDiscovery();
    super.dispose();
  }
}
