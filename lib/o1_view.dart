import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class O1ViewController extends StatefulWidget {
  const O1ViewController({super.key});

  @override
  O1ViewControllerState createState() => O1ViewControllerState();
}

class O1ViewControllerState extends State<O1ViewController> {
  TextEditingController addressController = TextEditingController();
  TextEditingController terminalFeedController = TextEditingController();
  AudioRecording? audioRecordingInstance;
  Uint8List audioData = Uint8List(0);
  RTCPeerConnection? connection;
  RTCDataChannel? dataChannel;
  bool isConnected = false;
  bool recordingPermission = false;
  bool terminal = false;
  String? address;

  @override
  void initState() {
    super.initState();
    terminalFeedController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zeroone App'),
      ),
      body: Column(
        children: [
          TextField(
            controller: terminalFeedController,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: 'Terminal Feed',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          const Text('Hold to start once connected.'),
          GestureDetector(
            onLongPressStart: (details) => buttonPress(),
            onLongPressEnd: (details) => buttonUp(),
            child: const Icon(Icons.circle, size: 100, color: Colors.yellow),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => settingsGear(),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => reconnectIcon(),
              ),
              IconButton(
                icon: Icon(terminal ? Icons.terminal : Icons.terminal_outlined),
                onPressed: () => terminalIcon(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void checkRecordingPerms() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      debugPrint('Requesting microphone permission');
      await Permission.microphone.request();
      status = await Permission.microphone.status;
    }
    debugPrint('Microphone permission: ${status.isGranted}');
    recordingPermission = status.isGranted;
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   address = null;
  //   debugPrint('Address: $address');
  //   if (address != null) {
  //     establishConnection();
  //   } else {
  //     //setAddress();
  //   }
  //   checkRecordingPerms();
  // }

  void setAddress() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set the Address'),
          content: TextField(
            controller: addressController,
            decoration: const InputDecoration(
              hintText: 'Enter IP Address Like 127.0.0.1:10001',
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Done'),
              onPressed: () {
                setState(() {
                  address = addressController.text;
                });
                establishConnection();
                checkRecordingPerms();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void reconnectIcon() {
    establishConnection();
  }

  void terminalIcon() {
    setState(() {
      terminal = !terminal;
      if (terminal) {
        terminalFeedController.text = '';
      }
    });
  }

  void settingsGear() {
    setAddress();
  }

  void buttonPress() async {
    if (isConnected && recordingPermission) {
      audioRecordingInstance = AudioRecording();
      await audioRecordingInstance!.startRecording();
      setState(() {});
    } else {
      if (!isConnected) {
        debugPrint('Not connected');
      }
      if (!recordingPermission) {
        debugPrint('No recording permission');
      }
    }
  }

  void buttonUp() async {
    if (isConnected && recordingPermission) {
      Uint8List? audio = await audioRecordingInstance!.stopRecording();

      if (audio == null) {
        debugPrint('No audio data recorded');
        return;
      } else {
        audioData = (await audioRecordingInstance!.stopRecording())!;
        sendAudio(audioData);
      }
    } else {
      debugPrint('Nothing to send... Not connected or no recording permission');
    }
  }

  Future<void> establishConnection() async {
    debugPrint('Establishing connection to $address');
    if (address != null) {
      try {
        connection = await createPeerConnection({
          'iceServers': [
            {
              'urls': [
                'stun:stun1.l.google.com:19302',
                'stun:stun2.l.google.com:19302'
              ]
            }
          ]
        });
        debugPrint('Created connection!');
        debugPrint(
            'Connection state: ${await connection!.getConnectionState()}');
        dataChannel =
            await connection!.createDataChannel('data', RTCDataChannelInit());
        debugPrint('Created data channel');
        dataChannel!.onDataChannelState = (state) {
          debugPrint('Data channel state: $state');
        };
        connection!.onDataChannel = (channel) {
          channel.onMessage = (message) {
            setState(() {
              debugPrint('Data channel message: ${message.text}');
              terminalFeedController.text += '\n>> ${message.text}';
            });
          };
        };
        setState(() {
          isConnected = true;
          debugPrint('Connected to $address');
        });
      } catch (e) {
        debugPrint('Error connecting to WebSocket: $e');
      }
    } else {
      setAddress();
    }
  }

  Uint8List createWAVHeader(int audioDataSize) {
    int headerSize = 44;
    int chunkSize = 36 + audioDataSize;
    int sampleRate = 16000;
    int numChannels = 1;
    int bitsPerSample = 16;
    int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    int blockAlign = numChannels * bitsPerSample ~/ 8;

    var header = BytesBuilder();

    header.add(utf8.encode('RIFF'));
    header.add(_int32ToBytes(chunkSize));
    header.add(utf8.encode('WAVE'));
    header.add(utf8.encode('fmt '));
    header.add(_int32ToBytes(16));
    header.add(_int16ToBytes(1));
    header.add(_int16ToBytes(numChannels));
    header.add(_int32ToBytes(sampleRate));
    header.add(_int32ToBytes(byteRate));
    header.add(_int16ToBytes(blockAlign));
    header.add(_int16ToBytes(bitsPerSample));
    header.add(utf8.encode('data'));
    header.add(_int32ToBytes(audioDataSize));

    return header.takeBytes();
  }

  Uint8List _int16ToBytes(int value) {
    var bytes = ByteData(2)..setInt16(0, value, Endian.little);
    return bytes.buffer.asUint8List();
  }

  Uint8List _int32ToBytes(int value) {
    var bytes = ByteData(4)..setInt32(0, value, Endian.little);
    return bytes.buffer.asUint8List();
  }

  void sendAudio(Uint8List audio) async {
    debugPrint('Sending audio');
    if (isConnected) {
      await dataChannel?.send(RTCDataChannelMessage(
        jsonEncode({
          'role': 'user',
          'type': 'audio',
          'format': 'bytes.raw',
          'start': true,
        }),
      ));
      debugPrint('Sent audio start');
      await dataChannel?.send(RTCDataChannelMessage.fromBinary(audio));
      debugPrint('Sent audio data');
      await dataChannel?.send(RTCDataChannelMessage(
        jsonEncode({
          'role': 'user',
          'type': 'audio',
          'format': 'bytes.raw',
          'end': true,
        }),
      ));
      debugPrint('Sent audio end');
    } else {
      debugPrint('Not connected');
    }
  }
}

class AudioRecording {
  FlutterSoundRecorder? _recorder;
  bool isRecording = false;

  Future<void> startRecording() async {
    Directory directory = await getApplicationDocumentsDirectory();
    String path = '${directory.path}/tempvoice.wav';

    debugPrint('Recording to: $path');

    _recorder = FlutterSoundRecorder();

    try {
      await _recorder!.openRecorder();
      await _recorder!.startRecorder(
        toFile: path,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );
      isRecording = true;
      debugPrint('Started recording');
    } catch (e) {
      debugPrint('Error starting recording: $e');
      await _recorder!.closeRecorder();
      _recorder = null;
    }
  }

  Future<String> getDocumentsDirectory() async {
    Directory directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<Uint8List?> stopRecording() async {
    if (isRecording && _recorder != null) {
      try {
        String? path = await _recorder!.stopRecorder();
        debugPrint('recording stopped: $path');
        _recorder!.closeRecorder();
        _recorder = null;
        isRecording = false;

        if (path != null) {
          File audioFile = File(path);
          Uint8List data = await audioFile.readAsBytes();
          debugPrint('Audio data length: ${data.length}');
          await audioFile.delete();
          return data;
        }
      } catch (e) {
        return null;
      }
    } else {
      return null;
    }
    return null;
  }
}
