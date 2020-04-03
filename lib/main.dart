import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MaterialApp(
    title: 'Object Detection',
    theme: ThemeData(
      primarySwatch: Colors.deepOrange,
      primaryColor: Colors.deepPurple,
    ),
    debugShowCheckedModeBanner: false,
    home: MyHomePage(
      title: 'Object Detection',
      camera: firstCamera,
    ),
  ));
}

const String ssd = "SSD MobileNet";
const String yolo = "Tiny Yolov2";

class MyHomePage extends StatefulWidget {
  final CameraDescription camera;
  MyHomePage({Key key, @required this.camera, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController _controller;
  Future<void> _initializeControllerFuture;

  String _model;
  File _image;
  String _way;
  bool _live = false;
  bool _busy = false;

  double _imageWidth;
  double _imageHeight;

  List _recognitions;

  List<Widget> stackChildren = [];

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _controller.initialize();
    _live = false;
    _busy = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> renderVideoBoxes(Size screen) {
    if (_recognitions == null) return [];

    double factorX = screen.width;
    double factorY = screen.height;

    return _recognitions.map((re) {
      return re["confidenceInClass"] < 0.2
          ? Icon(Icons.access_alarm)
          : Positioned(
              left: re["rect"]["x"] * factorX,
              top: re["rect"]["y"] * factorY,
              width: re["rect"]["w"] * factorX,
              height: re["rect"]["h"] * factorY,
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(
                  color: Colors.deepOrange,
                  width: 3,
                )),
                child: Text(
                  "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    background: Paint()..color = Colors.deepOrange,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            );
    }).toList();
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    double factorX = screen.width;
    double factorY = (_imageHeight / _imageWidth) * screen.width;

    return _recognitions.map((re) {
      return Positioned(
        left: re["rect"]["x"] * factorX,
        top: re["rect"]["y"] * factorY,
        width: re["rect"]["w"] * factorX,
        height: re["rect"]["h"] * factorY,
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(
            color: Colors.deepOrange,
            width: 3,
          )),
          child: Text(
            "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = Colors.deepOrange,
              color: Colors.white,
              fontSize: 15,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    if (_live) {
      stackChildren.clear();
      stackChildren.add(FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Container(
                width: size.width,
                height: size.height,
                child: CameraPreview(_controller));
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ));
      try{
        stackChildren.replaceRange(1, stackChildren.length, renderVideoBoxes(size));
      } catch (e) {
        stackChildren.addAll(renderVideoBoxes(size));
      }
    } else if (_image == null) {
      stackChildren.clear();
      stackChildren.add(Text("No input data"));
    } else {
      stackChildren.clear();
      stackChildren.add(
        Image.file(_image),
      );
      stackChildren.addAll(renderBoxes(size));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
          child: Column(children: <Widget>[
        Stack(children: stackChildren),
        Center(
            child: DropdownButton<String>(
          hint: new RichText(
              text: TextSpan(
                  text: "Select Object Detection Type!",
                  style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Open Sans',
                      fontSize: 25))),
          value: _model,
          icon: Icon(Icons.arrow_downward),
          iconSize: 24,
          elevation: 16,
          style: TextStyle(color: Colors.deepPurple),
          underline: Container(
            height: 2,
            color: Colors.deepPurpleAccent,
          ),
          onChanged: (String newValue) {
            setState(() {
              _model = newValue;
            });
          },
          items:
              <String>[ssd, yolo].map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
                value: value,
                child: Container(
                    child: RichText(
                        text: TextSpan(
                            text: value,
                            style: TextStyle(
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                fontFamily: 'Open Sans',
                                fontSize: 25)))));
          }).toList(),
        )),
        Center(
            child: DropdownButton<String>(
          hint: new RichText(
              text: TextSpan(
                  text: "Select Image Input!",
                  style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Open Sans',
                      fontSize: 25))),
          value: _way,
          icon: Icon(Icons.arrow_downward),
          iconSize: 24,
          elevation: 16,
          style: TextStyle(color: Colors.deepPurple),
          underline: Container(
            height: 2,
            color: Colors.deepPurpleAccent,
          ),
          onChanged: (String newValue) {
            setState(() {
              _way = newValue;
            });
          },
          items: <String>["Camera", "Video", "Gallery"]
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
                value: value,
                child: Container(
                    child: RichText(
                        text: TextSpan(
                            text: value,
                            style: TextStyle(
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                fontFamily: 'Open Sans',
                                fontSize: 25)))));
          }).toList(),
        )),
        Center(
            child: Container(
          child: new RaisedButton(
              shape: StadiumBorder(),
              color: Colors.deepOrangeAccent,
              child: Text("Go!"),
              onPressed: selectImage),
          padding: EdgeInsets.all(10),
        )),
      ])),
    );
  }

  loadModel() async {
    Tflite.close();
    try {
      String res;
      if (_model == yolo) {
        res = await Tflite.loadModel(
          model: "assets/tflite/yolov2_tiny.tflite",
          labels: "assets/tflite/yolov2_tiny.txt",
        );
      } else if (_model == ssd) {
        res = await Tflite.loadModel(
          model: "assets/tflite/ssd_mobilenet.tflite",
          labels: "assets/tflite/ssd_mobilenet.txt",
        );
      }
      print(res);
    } on PlatformException {
      print("Failed to load the model");
    }
  }

  selectImage() {
    if (_way == null) {
      setState(() {
        _recognitions = null;
        _image = null;
        _live = false;
        _busy = false;
        stackChildren.clear();
      });
    } else if (_way == "Video") {
      setState(() {
        _recognitions = null;
        _image = null;
        stackChildren.clear();
        _live = true;
        _busy = false;
      });
      selctFromVideo();
    } else if (_way == "Camera") {
      setState(() {
        _recognitions = null;
        _image = null;
        stackChildren.clear();
        _live = false;
        _busy = false;
      });
      selectFromCamera();
    } else if (_way == "Gallery") {
      _image = null;
      setState(() {
        _recognitions = null;
        stackChildren.clear();
        _live = false;
        _busy = false;
      });
      selectFromImagePicker();
    }
  }

  selctFromVideo() {
    loadModel();
    _controller.startImageStream((image) async {
      if (!_busy) {
        _busy = true;
        try {
          if (_model == yolo) {
            yolov2TinyVideo(image);
          } else if (_model == ssd) {
            ssdMobileNetVideo(image);
          }
        } catch (e) {}
      }
    });
  }

  selectFromCamera() async {
    if (_model == null) {
    } else {
      loadModel();
      var image = await ImagePicker.pickImage(source: ImageSource.camera);
      if (image == null) return;
      setState(() {});
      predictImage(image);
    }
  }

  selectFromImagePicker() async {
    if (_model == null) {
    } else {
      loadModel();
      var image = await ImagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      setState(() {});
      predictImage(image);
    }
  }

  predictImage(File image) async {
    if (image == null) return;
    if (_model == yolo) {
      await yolov2Tiny(image);
    } else if (_model == ssd) {
      await ssdMobileNet(image);
    }

    FileImage(image)
        .resolve(ImageConfiguration())
        .addListener((ImageStreamListener((ImageInfo info, bool _) {
          setState(() {
            _imageWidth = info.image.width.toDouble();
            _imageHeight = info.image.height.toDouble();
          });
        })));

    setState(() {
      _image = image;
    });
  }

  yolov2TinyVideo(CameraImage image) async {
    try {
      var recognitions = await Tflite.detectObjectOnFrame(
          bytesList: image.planes.map((plane) {
            return plane.bytes;
          }).toList(),
          model: "YOLO",
          imageHeight: image.height,
          imageWidth: image.width,
          imageMean: 0,
          imageStd: 255.0,
          threshold: 0.1,
          blockSize: 32,
          numResultsPerClass: 1,
          asynch: true);
      setState(() {
        stackChildren.clear();
        _recognitions = recognitions;
        _busy = false;
      });
    } catch (e) {}
  }

  yolov2Tiny(File image) async {
    var recognitions = await Tflite.detectObjectOnImage(
        path: image.path,
        model: "YOLO",
        threshold: 0.3,
        imageMean: 0.0,
        imageStd: 255.0,
        numResultsPerClass: 2);
    setState(() {
      _recognitions = recognitions;
    });
  }

  ssdMobileNetVideo(CameraImage image) async {
    try {
      var recognitions = await Tflite.detectObjectOnFrame(
          bytesList: image.planes.map((plane) {
            return plane.bytes;
          }).toList(),
          model: "SSDMobileNet",
          imageHeight: image.height,
          imageWidth: image.width,
          imageMean: 127.5,
          imageStd: 127.5,
          rotation: 90,
          threshold: 0.1,
          numResultsPerClass: 1,
          asynch: true);
      setState(() {
        _recognitions = recognitions;
        _busy = false;
      });
    } catch (e) {}
  }

  ssdMobileNet(File image) async {
    var recognitions = await Tflite.detectObjectOnImage(
        path: image.path,
        model: "SSDMobileNet",
        imageMean: 127.5,
        imageStd: 127.5,
        threshold: 0.4,
        numResultsPerClass: 2,
        asynch: true);
    setState(() {
      _recognitions = recognitions;
    });
  }
}
