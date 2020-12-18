import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path_provider/path_provider.dart';

import 'user_info.dart';
import 'user_result.dart';

part 'quiz.g.dart';

var quizzes = List<Quiz>();

enum QuizType {
  @JsonValue("audio")
  AUDIO,
  @JsonValue("mc")
  MULTIPLE_CHOICE,
}

@JsonSerializable()
class Quiz extends StatefulWidget {
  Quiz(this.title, this.type, this.length, this.choices, this.questions,
      this.correctAnswers, this.audios, this.images);

  factory Quiz.fromJson(Map<String, dynamic> json) => _$QuizFromJson(json);

  Map<String, dynamic> toJson() => _$QuizToJson(this);

  @JsonKey(required: true)
  final String title;

  @JsonKey(required: true)
  final QuizType type;

  @JsonKey(required: true)
  final List<String> questions;

  @JsonKey(required: true)
  final int length;

  // properties that only exists in quizzes with type MC:
  final List<String> correctAnswers;
  final List<String> audios;
  final List<String> images;
  final List<List<String>> choices;

  @override
  State<StatefulWidget> createState() => _QuizState();
}

class _QuizState extends State<Quiz> {
  int _questionNumber = 0;
  List<String> _choices;
  int _noOfQuestionsFilled = 0;
  bool _isRecording = false;
  FlutterSoundPlayer _audioPlayer;
  FlutterSoundRecorder _audioRecorder;

  void init() async {
    _audioPlayer = await FlutterSoundPlayer().openAudioSession();
    _audioRecorder = await FlutterSoundRecorder().openAudioSession();
  }

  @override
  void initState() {
    super.initState();
    _choices = List<String>.filled(widget.length, '', growable: true);
    init();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '第 ${_questionNumber + 1}/${widget.length} 題',
            style: TextStyle(fontSize: 22.0),
          ),
          leading: _backButton(),
        ),
        body: ListView(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                    _playAudioButton(),
                    _question(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _startRecordingAudioButton(),
                        _stopRecordingAudioButton()
                      ],
                    ),
                  ] +
                  _choiceButtons() +
                  [
                    Padding(
                      padding: EdgeInsets.all(5.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _prevQuestionButton(),
                          _submitButton(),
                          _nextQuestionButton(),
                        ],
                      ),
                    ),
                    _image(),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _backButton() {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text(
                '確認退出？',
                style: Theme.of(context).textTheme.headline1,
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: Colors.transparent,
                  ),
                  onPressed: () {
                    Navigator.popUntil(context, ModalRoute.withName('/'));
                  },
                  child: Text('退出'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: Colors.transparent,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('取消'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Widget _playAudioButton() {
    return widget.type == QuizType.AUDIO
        ? Container()
        : Padding(
            padding: EdgeInsets.all(2.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0)),
                side: BorderSide(color: Colors.white, width: 1.0),
                minimumSize: Size(150.0, 25.0),
                primary: Colors.lightBlue,
              ),
              child: Text('播放聲音'),
              onPressed: () {
                _audioPlayer.openAudioSession().then((player) async {
                  await player.startPlayer(
                      fromURI:
                          'assets/audios/${widget.audios[_questionNumber]}.mp3');
                });
              },
            ),
          );
  }

  Widget _question() {
    return Padding(
      padding: EdgeInsets.all(20.0),
      child: Text(
        widget.questions[_questionNumber],
        style: TextStyle(
          fontSize: 25.0,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _startRecordingAudioButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(200.0, 50.0),
          primary: _isRecording ? Colors.grey : Colors.blue,
        ),
        child: Text("錄製答案"),
        onPressed: () async {
          if (!_isRecording) {
            setState(() {
              _isRecording = true;
            });
            final tmpPath = await getTemporaryDirectory();
            final path = Directory('${tmpPath.path}/quiz_recordings');
            await path.create();
            final file =
                File('${path.path}/${_questionNumber+1}.mp3');
            file.writeAsStringSync('123');
            await _audioRecorder.startRecorder(toFile: file.path);
          }
        },
      ),
    );
  }

  // Note: Recompile with -Xlint:deprecation for details.
  Widget _stopRecordingAudioButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(50.0, 50.0),
          primary: _isRecording ? Colors.red : Colors.grey,
        ),
        child: Icon(Icons.stop, color: Colors.black),
        onPressed: () async {
          if (_isRecording) {
            setState(() {
              _isRecording = false;
            });
            await _audioRecorder.stopRecorder();
          }
        },
      ),
    );
  }

  List<Widget> _choiceButtons() {
    return widget.type == QuizType.AUDIO
        ? []
        : widget.choices[_questionNumber]
            .map(
              (choice) => Padding(
                padding: EdgeInsets.zero,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    primary: choice == _choices[_questionNumber]
                        ? Colors.purple
                        : Colors.lightBlue,
                    minimumSize: const Size(350.0, 35.0),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15.0)),
                    ),
                    side: BorderSide(color: Colors.white54, width: 3.0),
                  ),
                  onPressed: () async {
                    await _audioPlayer.closeAudioSession();
                    await _audioPlayer.stopPlayer();

                    if (_choices[_questionNumber] == '') {
                      setState(() {
                        _noOfQuestionsFilled++;
                      });
                    }
                    setState(() {
                      _choices[_questionNumber] = choice;
                    });
                  },
                  child: Text(
                    choice,
                    style: TextStyle(fontSize: 20.0, color: Colors.white),
                  ),
                ),
              ),
            )
            .toList(); // choices
  }

  Widget _prevQuestionButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
          primary: _questionNumber == 0 ? Colors.blueGrey : Colors.lightBlue,
          shape: CircleBorder(),
          minimumSize: Size(50.0, 50.0)),
      child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 50),
      onPressed: () {
        if (_questionNumber > 0)
          setState(() {
            _questionNumber--;
          });
      },
    );
  }

  Widget _submitButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        primary: _noOfQuestionsFilled == widget.length
            ? Colors.green
            : Colors.blueGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: Size(100.0, 50.0),
      ),
      child: Text('遞交'),
      onPressed: () {
        if (_noOfQuestionsFilled == widget.length) {
          int score = 0;
          for (int i = 0; i < widget.length; ++i) {
            if (_choices[i] == widget.correctAnswers[i]) {
              score++;
            }
          }
          Navigator.pushNamed(
            context,
            '/summary',
            arguments: UserResult(
              currentUserInfo.name,
              currentUserInfo.dateOfBirth,
              currentUserInfo.gender,
              score,
              widget.title,
              widget.length,
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                content: Text(
                  '請先完成所有題目',
                  style: Theme.of(context).textTheme.headline1,
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      primary: Colors.transparent,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('好'),
                  )
                ],
              );
            },
          );
        }
      },
    );
  }

  Widget _nextQuestionButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
          primary: _questionNumber == widget.length - 1
              ? Colors.blueGrey
              : Colors.lightBlue,
          shape: CircleBorder(),
          minimumSize: Size(50.0, 50.0)),
      child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 50),
      onPressed: () {
        if (_questionNumber + 1 < widget.length)
          setState(() {
            _questionNumber++;
          });
      },
    );
  }

  Widget _image() {
    return widget.images == null
        ? Container()
        : Padding(
            padding: EdgeInsets.all(10.0),
            child: Image.asset(
              'assets/images/${widget.images[_questionNumber]}',
            ),
          );
  }
}