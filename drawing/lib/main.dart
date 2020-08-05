import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'spc/sscreen.dart';

//import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'SPC-1000',
      home: new MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Uint8List bmp;
  Uint8List buffer;
  int color;
  BMP332Header header;
  Random r = Random();
  double scale = 0.5;
  Timer _timer;
  Key _key;
  int _a = 0;
  Screen screen;
  @override
  void initState() {
    super.initState();
    header = BMP332Header(256, 192);
    color = r.nextInt(255);
    buffer = Uint8List(header._width * header._height);
    screen = new Screen(buffer);
    scale = 0.5;
    _timer = new Timer.periodic(
        const Duration(milliseconds: 32),
        (Timer timer) => setState(() {
              color = r.nextInt(16);
              {
                for (int i = 0; i < header._height - 1; i++) {
                  buffer.fillRange(i * header._width, (i + 1) * header._width,
                      (i + color) % 16);
                }
                screen.dump();
              }
              scale = scale == 0.4 ? 0.41 : 0.4;
              _a++;
            }));
  }

  // bool _isPlayerReady = false;
  // PlayerState _playerState;
  // YoutubeMetaData _videoMetaData;
  // void listener() {
  //   if (_isPlayerReady && mounted && !_controller.value.isFullScreen) {
  //     setState(() {
  //       _playerState = _controller.value.playerState;
  //       _videoMetaData = _controller.metadata;
  //     });
  //   }
  // }

  // YoutubePlayerController _controller = YoutubePlayerController(
  //   initialVideoId: 'iLnmTe5Q2Qw',
  //   flags: YoutubePlayerFlags(
  //     autoPlay: true,
  //     mute: true,
  //   ),
  // );
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text('SPC-1000'),
      ),
      body: Center(
        child: ListView(
          children: <Widget>[
            Image.memory(
              header.appendBitmap(buffer),
              scale: scale,
            ),
            Text("$_a"),
//            Text(buffer.toString()),
          ],
        ),
      ),
    );
  }
}

class BMP332Header {
  BMP332Header(this._width, this._height) : assert(_width & 3 == 0) {
    int baseHeaderSize = 54;
    _totalHeaderSize = baseHeaderSize + 1024; // base + color map
    int fileLength = _totalHeaderSize + _width * _height; // header + bitmap
    _bmp = new Uint8List(fileLength);
    ByteData bd = _bmp.buffer.asByteData();
    bd.setUint8(0, 0x42);
    bd.setUint8(1, 0x4d);
    bd.setUint32(2, fileLength, Endian.little); // file length
    bd.setUint32(10, _totalHeaderSize, Endian.little); // start of the bitmap
    bd.setUint32(14, 40, Endian.little); // info header size
    bd.setUint32(18, _width, Endian.little);
    bd.setUint32(22, _height, Endian.little);
    bd.setUint16(26, 1, Endian.little); // planes
    bd.setUint32(28, 8, Endian.little); // bpp
    bd.setUint32(30, 0, Endian.little); // compression
    bd.setUint32(34, _width * _height, Endian.little); // bitmap size
    var colors = [
      /* BLACK */
      0xff000000,
      /* GREEN */
      0xff07ff00,
      /* YELLOW */
      0xffffff00,
      /* BLUE */
      0xff3b08ff,
      /* RED */
      0xffcc003b,
      /* BUFF */
      0xffffffff,
      /* CYAN */
      0xff07e399,
      /* MAGENTA */
      0xffff1cff,
      /* ORANGE */
      0xffff8100,
      /* GREEN */
      0xff07ff00,
      /* BUFF */
      0xffffffff,
      /* ALPHANUMERIC DARK GREEN */
      0xff004400,
      /* ALPHANUMERIC BRIGHT GREEN */
      0xff07ff00,
      /* ALPHANUMERIC DARK ORANGE */
      0xff910000,
      /* ALPHANUMERIC BRIGHT ORANGE */
      0xffff8100
    ];
    // leave everything else as zero
    // there are 256 possible variations of pixel
    // build the indexed color map that maps from packed byte to RGBA32
    // better still, create a lookup table see: http://unwind.se/bgr233/
    for (int rgb = 0; rgb < 256; rgb++) {
      int offset = baseHeaderSize + rgb * 4;

      int red = rgb & 0xe0;
      int green = rgb << 3 & 0xe0;
      int blue = rgb & 6 & 0xc0;
      bd.setUint8(offset + 3, 255); // A
      bd.setUint8(offset + 2, red); // R
      bd.setUint8(offset + 1, green); // G
      bd.setUint8(offset, blue); // B
      if (rgb < colors.length) bd.setUint32(offset, colors[rgb]);
    }
  }

  Uint8List _bmp;
  int _height;
  int _totalHeaderSize;
  int _width; // NOTE: width must be multiple of 4 as no account is made for bitmap padding

  /// Insert the provided bitmap after the header and return the whole BMP
  Uint8List appendBitmap(Uint8List bitmap) {
    int size = _width * _height;
    assert(bitmap.length == size);
    _bmp.setRange(_totalHeaderSize, _totalHeaderSize + size, bitmap);
    return _bmp;
  }
}
