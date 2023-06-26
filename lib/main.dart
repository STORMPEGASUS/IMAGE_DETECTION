import 'dart:io';
import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late ImagePicker imagePicker;
  File? _image;
  var image;
  dynamic objectDetector;
  _imgFromCamera() async {
    XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      _image = File(pickedFile.path);
      doObjectDetection();
    }
  }

  _imgFromGallery() async {
    XFile? pickedFile =
        await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _image = File(pickedFile.path);
      doObjectDetection();
    }
  }

  @override
  void initState() {
    super.initState();
    imagePicker = ImagePicker();

    createObjectDetector();
  }

  @override
  void dispose() {
    super.dispose();
  }

  late List<DetectedObject> objects;

  Future<String> _getModel(String assetPath) async {
    if (io.Platform.isAndroid) {
      return 'flutter_assets/$assetPath';
    }
    final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
    await io.Directory(dirname(path)).create(recursive: true);
    final file = io.File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }

// new object detector function
  createObjectDetector() async {
    final modelPath = await _getModel('assets/ml/mobilenet2.tflite');
    final options = LocalObjectDetectorOptions(
      modelPath: modelPath,
      classifyObjects: true,
      multipleObjects: true,
      mode: DetectionMode.single,
    );
    objectDetector = ObjectDetector(options: options);
  }

  doObjectDetection() async {
    InputImage inputImage = InputImage.fromFile(_image!);
    objects = await objectDetector.processImage(inputImage);

    for (DetectedObject detectedObject in objects) {
      final rect = detectedObject.boundingBox;
      final trackingId = detectedObject.trackingId;

      for (Label label in detectedObject.labels) {
        print('${label.text} ${label.confidence}');
      }
    }
    setState(() {
      _image;
    });
    drawRectanglesAroundObjects();
  }

  drawRectanglesAroundObjects() async {
    image = await _image?.readAsBytes();
    image = await decodeImageFromList(image);
    setState(() {
      image;
      objects;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('IMAGES/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(
              width: 100,
            ),
            Container(
              margin: const EdgeInsets.only(top: 80),
              child: Stack(
                children: <Widget>[
                  Center(
                    child: ElevatedButton(
                      onLongPress: _imgFromCamera,
                      onPressed: _imgFromGallery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: Container(
                        width: 350,
                        height: 350,
                        margin: const EdgeInsets.only(
                          top: 45,
                        ),
                        child: image != null
                            ? Center(
                                child: FittedBox(
                                  child: SizedBox(
                                    width: image.width.toDouble(),
                                    height: image.width.toDouble(),
                                    child: CustomPaint(
                                      painter: ObjectPainter(
                                          objectList: objects,
                                          imageFile: image),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.pinkAccent,
                                width: 350,
                                height: 350,
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.black,
                                  size: 53,
                                ),
                              ),
                      ),

                      // Container(
                      //   margin: const EdgeInsets.only(top: 8),
                      //   child: _image != null
                      //       ? Image.file(
                      //           _image!,
                      //           width: 350,
                      //           height: 350,
                      //           fit: BoxFit.fill,
                      //         )
                      //       : Container(
                      //           width: 350,
                      //           height: 350,
                      //           color: Colors.pinkAccent,
                      //           child: const Icon(
                      //             Icons.camera_alt,
                      //             color: Colors.black,
                      //             size: 100,
                      //           ),
                      //         ),
                      // ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ObjectPainter extends CustomPainter {
  List<DetectedObject> objectList;
  dynamic imageFile;
  ObjectPainter({required this.objectList, @required this.imageFile});

  @override
  void paint(Canvas canvas, Size size) {
    if (imageFile != null) {
      canvas.drawImage(imageFile, Offset.zero, Paint());
    }
    Paint p = Paint();
    p.color = Colors.red;
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 5;

    for (DetectedObject rectangle in objectList) {
      canvas.drawRect(rectangle.boundingBox, p);
      var list = rectangle.labels;
      for (Label label in list) {
        print("${label.text}   ${label.confidence.toStringAsFixed(2)}");
        TextSpan span = TextSpan(
            text: label.text,
            style: const TextStyle(
                fontSize: 50,
                color: Color.fromARGB(255, 255, 255, 255),
                fontWeight: FontWeight.w600));
        TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas,
            Offset(rectangle.boundingBox.left, rectangle.boundingBox.top));
        break;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
