//
//  audio_recording.dart
//  o1flutter project for o1 flutter app
//
//  Created by Anthony Libby on 2024-05-18.
//
//  Based on:
//  AudioRecording.swift
//  zeroone-app
//
//  Created by Elad Dekel on 2024-05-10.
//

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecording {
  FlutterSoundRecorder? _recorder;
  bool isRecording = false;

  Future<void> startRecording() async {
    Directory directory = await getApplicationDocumentsDirectory();
    String path = '${directory.path}/tempvoice.wav';

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
    } catch (e) {
      print('Error recording');
      print(e.toString());
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
        _recorder!.closeRecorder();
        _recorder = null;
        isRecording = false;

        if (path != null) {
          File audioFile = File(path);
          Uint8List data = await audioFile.readAsBytes();
          await audioFile.delete();
          return data;
        }
      } catch (e) {
        print(e.toString());
        return null;
      }
    } else {
      print('Not recording');
      return null;
    }
    return null;
  }
}
