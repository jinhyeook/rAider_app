import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CameraTestPage extends StatefulWidget {
  @override
  _CameraTestPageState createState() => _CameraTestPageState();
}

class _CameraTestPageState extends State<CameraTestPage> {
  File? _image;

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('카메라 테스트')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _takePicture,
            child: Text('카메라로 사진 찍기'),
          ),
          if (_image != null)
            Image.file(_image!),
        ],
      ),
    );
  }
}
