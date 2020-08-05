import 'package:flutter/material.dart';
// ignore: unused_import
import 'dart:ui' as ui;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
      ),
      home: MyHomePage(title: 'Provider Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ImageInfo info; //image information
  List<BlendMode> blendModes =
      BlendMode.values; //All mixed modes are converted to list

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Image.asset("images/yuan.png")
        .image
        .resolve(createLocalImageConfiguration(context))
        .addListener(
            new ImageStreamListener((ImageInfo image, bool synchronousCall) {
      setState(() {
        info = image; // Refresh status
      });
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridView.builder(
        itemCount: blendModes.length * 500,
        padding: EdgeInsets.only(top: 10.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
        ),
        itemBuilder: getItemBuilder,
      ),
    );
  }

  Widget getItemBuilder(BuildContext context, int index) {
    return Column(
      children: <Widget>[
        RawImage(
          image: info?.image,
          color: Colors.red,
          width: 40,
          height: 40,
          colorBlendMode: blendModes[(index % blendModes.length)],
          fit: BoxFit.cover,
        ),
        Container(
          padding: EdgeInsets.only(top: 10.0),
          child: Text(
            blendModes[(index % blendModes.length)].toString().split("\.")[1],
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.0,
            ),
          ),
        ),
      ],
    );
  }
}
