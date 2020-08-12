import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // for date format
import 'package:lottie/lottie.dart';
import 'package:screen/screen.dart';

void main() {
  Lottie.traceEnabled = true;
  Screen.keepOn(true);
  runApp(MaterialApp(title: "자연탐사대", home: HomeScreen()));
}

class HomeScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return HomeScreenState();
  }
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Animation animation;
  AnimationController animationController;
  AnimationController _controller;
  HomeScreenState();

  _currentTime() {
    var time = DateTime.now().toLocal();
    return " ${DateFormat('hh:mm:ss').format(time)}";
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    animationController =
        AnimationController(vsync: this, duration: Duration(seconds: 2));
    animationController.addListener(() {
      //setstate
      if (animationController.isCompleted)
        animationController.reverse();
      else if (animationController.isDismissed) animationController.forward();
      setState(() {});
    });
    animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );
    animation = Tween(begin: -0.5, end: 0.5).animate(animation);
    return Scaffold(
        appBar: AppBar(
          title: Center(child: Text("자연탐사대")),
          backgroundColor: Colors.deepOrange,
          elevation: 0.0,
        ),
        body: Container(
            color: Colors.deepOrange,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Transform(
                      alignment: FractionalOffset(0.5, 0.1),
                      transform: Matrix4.rotationZ(animation.value),
                      child: Lottie.network(
                        'https://assets8.lottiefiles.com/packages/lf20_ilbFbZ.json',
                        onLoaded: (composition) {
                          _controller.duration = composition.duration;
                          _controller.repeat();
                        },
                        width: 300,
                        height: 300,
                      )),
                  Transform(
                    alignment: FractionalOffset(0.5, 0.1),
                    transform: Matrix4.rotationZ(-animation.value),
                    child: Material(
                        borderRadius: BorderRadius.all(Radius.circular(50.0)),
                        elevation: 10.0,
                        color: Colors.brown.shade900,
                        child: Container(
                            width: 320,
                            height: 220,
                            child: Center(
                              child: Text(_currentTime(),
                                  style: TextStyle(
                                    fontSize: 70.0,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  )),
                            ))),
                  ),
                  // Transform(
                  //   alignment: FractionalOffset(0.5, 0.1),
                  //   transform: Matrix4.rotationZ(animation.value),
                  //   child: Image.asset(
                  //     'images/spoon.png',
                  //   ),
                  // )
                ],
              ),
            )));
  }
}
