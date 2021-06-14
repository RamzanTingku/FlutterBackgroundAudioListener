import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

_backgroundTaskEntrypoint() {
  AudioServiceBackground.run(() => BackgroundTask());
}

class BackgroundTask extends BackgroundAudioTask {

  String lastWords = '';
  String lastError = '';
  String lastStatus = '';
  String currentLocaleId = '';
  int resultListened = 0;
  List<LocaleName> localeNames = [];
  final SpeechToText speech = SpeechToText();
  final FlutterTts flutterTts = FlutterTts();
  final _audioPlayer = AudioPlayer();

  void startListening() {
    lastWords = '';
    lastError = '';
    speech.listen(
        onResult: resultListener,
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
        localeId: currentLocaleId,
        cancelOnError: true,
        listenMode: ListenMode.confirmation);
  }

  void stopListening() {
    speech.stop();
  }

  void cancelListening() {
    speech.cancel();
  }

  void resultListener(SpeechRecognitionResult result) async {
    ++resultListened;
    lastWords = '${result.recognizedWords} - ${result.finalResult}';

    print('Result count: $resultListened');
    print('Success Result: $lastWords');

    try {
      await flutterTts.awaitSpeakCompletion(true);
      await flutterTts.setLanguage("en-US");
      await flutterTts.setPitch(1);
      var speakResult = await flutterTts.speak(lastWords);
      print("speakResult: $speakResult");
    } catch (e) {
      print(e);
    }

    /*Future.delayed(Duration(seconds: 5)).then((value) async {
      if(!speech.isListening)
        await onPlay();
    });*/

  }

  void errorListener(SpeechRecognitionError error) {
    lastError = '${error.errorMsg} - ${error.permanent}';
    print('Result count: $resultListened');
    print('Error Result: $lastError');

    Future.delayed(Duration(seconds: 5)).then((value) async {
      if(!speech.isListening)
        await onPlay();
    });
  }

  void statusListener(String status) {
    lastStatus = '$status';
  }


  Future<void> initSpeechState() async {
    var hasSpeech = await speech.initialize(
        onError: errorListener,
        onStatus: statusListener,
        debugLogging: true,
        finalTimeout: Duration(milliseconds: 0));

    if (hasSpeech) {
      localeNames = await speech.locales();

      var systemLocale = await speech.systemLocale();
      currentLocaleId = systemLocale?.localeId ?? '';
    }
    await _audioPlayer.setAsset('hello.mp3');
    _audioPlayer.play();
  }

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    AudioServiceBackground.setState(
        controls: [MediaControl.pause, MediaControl.stop],
        playing: true,
        processingState: AudioProcessingState.connecting);


    await initSpeechState();

    AudioServiceBackground.setState(
        controls: [MediaControl.pause, MediaControl.stop],
        playing: true,
        processingState: AudioProcessingState.ready);
  }

  @override
  Future<void> onStop() async {
    AudioServiceBackground.setState(
        controls: [],
        playing: false,
        processingState: AudioProcessingState.ready);

    cancelListening();
    await super.onStop();
  }
  @override
  Future<void> onPlay() async{
    AudioServiceBackground.setState(
        controls: [MediaControl.pause, MediaControl.stop],
        playing: true,
        processingState: AudioProcessingState.ready);

    if(!speech.isListening)
      startListening();

    return super.onPlay();
  }

  @override
  Future<void> onPause() async{
    AudioServiceBackground.setState(
        controls: [MediaControl.play, MediaControl.stop],
        playing: false,
        processingState: AudioProcessingState.ready);

    stopListening();
    return super.onPause();
  }
}

class BackgroundTaskPractice extends StatefulWidget {
  @override
  _BackgroundTaskPracticeState createState() => _BackgroundTaskPracticeState();
}

class _BackgroundTaskPracticeState extends State<BackgroundTaskPractice> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Scaffold(
        appBar: AppBar(title: Text("Background Music"),
          actions: [IconButton(icon: Icon(Icons.stop), onPressed: () {
            AudioService.stop();
          })
          ],
        ),
        body: Center(
          child: StreamBuilder<PlaybackState>(
              stream: AudioService.playbackStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                if (playing)
                  return ElevatedButton(child: Text("Pause"), onPressed: () {AudioService.pause();});
                else
                  return ElevatedButton(child: Text("Play"), onPressed: () {
                    if(AudioService.running){
                      AudioService.play();
                    }else{
                      AudioService.start(backgroundTaskEntrypoint: _backgroundTaskEntrypoint);
                    }
                  });

              }
          ),
        )
    ));
  }
}
