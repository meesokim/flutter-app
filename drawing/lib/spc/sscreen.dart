library spc;

import "dart:typed_data";

class Color {
  final int r, g, b;
  const Color(this.r, this.g, this.b);
}

class Screen {
  final List<int> _semiGrFont0 = new List<int>(12 * 16);
  final List<int> _semiGrFont1 = new List<int>(12 * 64);
  static const int SCREEN_TEXT_START = 0;
  static const int SCREEN_ATTR_START = 0x800;
  int _flash = 0;
  int gmode;
  bool _gm0, _gm1, _ag = false, _css;
  int _page = 0;
  final List<int> cgram = new List<int>(0x1fff);
  Uint8List _pixels;

  static const int ATTR_INV = 0x1; // white
  static const int ATTR_CSS = 0x2; // cyan blue
  static const int ATTR_SEM = 0x4;
  static const int ATTR_EXT = 0x8;

  final List<Color> _palette = const [
    const Color(0x07, 0xff, 0x00),
    /* GREEN */
    const Color(0xff, 0xff, 0x00),
    /* YELLOW */
    const Color(0x3b, 0x08, 0xff),
    /* BLUE */
    const Color(0xcc, 0x00, 0x3b),
    /* RED */
    const Color(0xff, 0xff, 0xff),
    /* BUFF */
    const Color(0x07, 0xe3, 0x99),
    /* CYAN */
    const Color(0xff, 0x1c, 0xff),
    /* MAGENTA */
    const Color(0xff, 0x81, 0x00),
    /* ORANGE */
    const Color(0x00, 0x00, 0x00),
    /* BLACK */
    const Color(0x07, 0xff, 0x00),
    /* GREEN */
    const Color(0x00, 0x00, 0x00),
    /* BLACK */
    const Color(0xff, 0xff, 0xff),
    /* BUFF */
    const Color(0x00, 0x7c, 0x00),
    /* ALPHANUMERIC DARK GREEN */
    const Color(0x07, 0xff, 0x00),
    /* ALPHANUMERIC BRIGHT GREEN */
    const Color(0x91, 0x00, 0x00),
    /* ALPHANUMERIC DARK ORANGE */
    const Color(0xff, 0x81, 0x00) /* ALPHANUMERIC BRIGHT ORANGE */
  ];

  Screen(Uint8List pixels) {
    _pixels = pixels;
    _initFonts();
    for (int i = 0; i < 0x1fff; i++) cgram[i] = 0;
  }

  void _initFonts() {
    for (int i = 1; i < 16; i++)
      for (int j = 0; j < 12; j++) {
        int val = 0;
        if (j < 6) {
          val |= ((i & 0x08) != 0 ? 0xf0 : 0x00);
          val |= ((i & 0x04) != 0 ? 0x0f : 0x00);
        } else {
          val |= ((i & 0x02) != 0 ? 0xf0 : 0x00);
          val |= ((i & 0x01) != 0 ? 0x0f : 0x00);
        }
        _semiGrFont0[i * 12 + j] = val & 0xff;
      }

    for (int i = 1; i < 64; i++)
      for (int j = 0; j < 12; j++) {
        int val = 0;
        if (j < 4) {
          val |= ((i & 0x20) > 0 ? 0xf0 : 0x00);
          val |= ((i & 0x10) > 0 ? 0x0f : 0x00);
        } else if (j < 8) {
          val |= ((i & 0x08) > 0 ? 0xf0 : 0x00);
          val |= ((i & 0x04) > 0 ? 0x0f : 0x00);
        } else {
          val |= ((i & 0x02) > 0 ? 0xf0 : 0x00);
          val |= ((i & 0x01) > 0 ? 0x0f : 0x00);
        }
        _semiGrFont1[i * 12 + j] = val & 0xff;
      }
  }

  void setMode(int a) {
    _gm0 = ((a & (1 << 2)) != 0);
    _gm1 = ((a & (1 << 1)) != 0);
    _ag = ((a & (1 << 3)) != 0);
    _css = ((a & (1 << 7)) != 0);
    _page = ((a >> 4) & 0x3);
    gmode = a;
  }

  void flash() {
    _flash = _flash == 0x7f ? 0xff : 0x7f;
  }

  void border(int value) {
    var color = _palette[value];
  }

  void out8(int addr, int b) {
    if (addr == 0x2000)
      setMode(b);
    else
      cgram[addr & 0x1fff] = b & 0xff;
  }

  int in8(int addr) {
    return cgram[addr & 0x1fff];
  }

  void dump() {
    var data = _pixels;
    var pos = 0;
    var bg, fg;
    border(8);
    if (_ag == false) {
      for (int y = 0; y < 16; y++)
        for (int h = 0; h < 12; h++) {
          for (int x = 0; x < 32; x++) {
            var attr = cgram[x + y * 32 + SCREEN_ATTR_START + _page * 0x200];
            var ch = cgram[x + y * 32 + SCREEN_TEXT_START + _page * 0x200];
            var byte = 0;
            if ((attr & ATTR_SEM) != 0) {
              bg = 8;
              if ((attr & ATTR_EXT) != 0) {
                fg = (attr & 2) << 1 | ((ch & 0xc0) >> 6);
                byte = _semiGrFont1[(ch & 0x3f) * 12 + h];
              } else {
                fg = ((ch & 0x70) >> 4);
                byte = _semiGrFont0[(ch & 0x0f) * 12 + h];
              }
            } else {
              int cix = (attr & ATTR_CSS) >> 1;
              if ((attr & ATTR_INV) == 0) {
                bg = 12 + cix * 2;
                fg = 12 + cix * 2 + 1;
              } else {
                fg = 12 + cix * 2;
                bg = 12 + cix * 2 + 1;
              }
              if (ch < 32 && (attr & ATTR_EXT == 0)) ch = 32;
              if (((attr & ATTR_EXT) != 0) && (ch < 96)) ch += 128;
              if (ch >= 96 && ch < 128)
                byte = cgram[0x1600 + (ch - 96) * 16 + h];
              else if (ch >= 128 && ch < 224)
                byte = cgram[0x1000 + (ch - 128) * 16 + h];
              else if (ch >= 32) byte = CGROM[(ch - 32) * 12 + h];
            }
            if (byte == null) byte = 0;
            for (var mask = 0x80; mask != 0; mask >>= 1) {
              var color = (byte & mask) != 0 ? fg : bg;
              data[pos++] = color;
            }
          }
          pos = (h + y * 12) * 256;
        }
    } else {
      var byte;
      var fg, bg;
      bg = 8;
      fg = (_css ? 4 : 0);
      border(_css ? 4 : 0);
      for (int y = 0; y < 192; y++) {
        for (int x = 0; x < 32; x++) {
          byte = cgram[y * 32 + x];
          if (byte == null) byte = 0;
          if (_gm0 == true) {
            for (var mask = 0x80; mask != 0; mask >>= 1) {
              data[pos++] = (byte & mask) != 0 ? fg : bg;
            }
          } else {
            for (int c = 3; c >= 0; c--) {
              var color = ((byte & (0x3 << c)) >> c);
              data[pos++] = data[pos++] = color;
            }
          }
        }
        pos = y * 256;
      }
    }
  }

  static const List<int> CGROM = const [
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //32
    0x00, 0x00, 0x00, 0x08, 0x08, 0x08, 0x08, 0x08, 0x00, 0x08, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x14, 0x14, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x14, 0x14, 0x3E, 0x14, 0x3E, 0x14, 0x14, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x08, 0x1E, 0x28, 0x1C, 0x0A, 0x3C, 0x08, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x32, 0x32, 0x04, 0x08, 0x10, 0x26, 0x26, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x10, 0x28, 0x10, 0x28, 0x26, 0x24, 0x1A, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x04, 0x08, 0x10, 0x10, 0x10, 0x08, 0x04, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x10, 0x08, 0x04, 0x04, 0x04, 0x08, 0x10, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x08, 0x1C, 0x3E, 0x1C, 0x08, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x08, 0x08, 0x3E, 0x08, 0x08, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x08, 0x10, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3E, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x02, 0x02, 0x04, 0x08, 0x10, 0x20, 0x20, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x0C, 0x12, 0x12, 0x12, 0x12, 0x12, 0x0C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x08, 0x18, 0x08, 0x08, 0x08, 0x08, 0x1C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x22, 0x02, 0x1C, 0x20, 0x20, 0x3E, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x22, 0x02, 0x0C, 0x02, 0x22, 0x1C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x04, 0x0C, 0x14, 0x24, 0x3E, 0x04, 0x04, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3E, 0x20, 0x3C, 0x02, 0x02, 0x22, 0x1C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x22, 0x20, 0x3C, 0x22, 0x22, 0x1C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3E, 0x02, 0x02, 0x04, 0x08, 0x08, 0x08, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x22, 0x22, 0x1C, 0x22, 0x22, 0x1C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x22, 0x22, 0x1E, 0x02, 0x22, 0x1C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x08, 0x10, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x04, 0x08, 0x10, 0x20, 0x10, 0x08, 0x04, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x3E, 0x00, 0x3E, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x10, 0x08, 0x04, 0x02, 0x04, 0x08, 0x10, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x22, 0x02, 0x04, 0x08, 0x00, 0x08, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x22, 0x22, 0x06, 0x0A, 0x0A, 0x06, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x08, 0x14, 0x22, 0x3E, 0x22, 0x22, 0x22, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3C, 0x22, 0x22, 0x3C, 0x22, 0x22, 0x3C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x22, 0x20, 0x20, 0x20, 0x22, 0x1C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3C, 0x12, 0x12, 0x12, 0x12, 0x12, 0x3C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3E, 0x20, 0x20, 0x3C, 0x20, 0x20, 0x3E, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3E, 0x20, 0x20, 0x3C, 0x20, 0x20, 0x20, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x22, 0x20, 0x26, 0x22, 0x22, 0x1E, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x22, 0x22, 0x22, 0x3E, 0x22, 0x22, 0x22, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x08, 0x08, 0x08, 0x08, 0x08, 0x1C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x0E, 0x04, 0x04, 0x04, 0x04, 0x24, 0x18, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x22, 0x24, 0x28, 0x30, 0x28, 0x24, 0x22, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3E, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x22, 0x36, 0x2A, 0x2A, 0x22, 0x22, 0x22, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x22, 0x32, 0x2A, 0x26, 0x22, 0x22, 0x22, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3E, 0x22, 0x22, 0x22, 0x22, 0x22, 0x3E, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3C, 0x22, 0x22, 0x3C, 0x20, 0x20, 0x20, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x22, 0x22, 0x22, 0x2A, 0x26, 0x1E, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3C, 0x22, 0x22, 0x3C, 0x28, 0x24, 0x22, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x22, 0x20, 0x1C, 0x02, 0x22, 0x1C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3E, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x22, 0x22, 0x22, 0x14, 0x14, 0x08, 0x08, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x22, 0x22, 0x22, 0x2A, 0x2A, 0x36, 0x22, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x22, 0x22, 0x14, 0x08, 0x14, 0x22, 0x22, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x22, 0x22, 0x14, 0x08, 0x08, 0x08, 0x08, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3E, 0x02, 0x04, 0x08, 0x10, 0x20, 0x3E, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1C, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x38, 0x08, 0x08, 0x08, 0x08, 0x08, 0x38, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x08, 0x14, 0x22, 0x08, 0x08, 0x08, 0x08, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x10, 0x20, 0x7F, 0x20, 0x10, 0x00, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //64
    0x00, 0x00, 0x00, 0x3C, 0x42, 0x42, 0x42, 0x42, 0x3C, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3C, 0x7E, 0x7E, 0x7E, 0x7E, 0x3C, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x08, 0x08, 0x08, 0x2A, 0x1C, 0x08, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x08, 0x04, 0x7E, 0x04, 0x08, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10,
    0x10, 0x10, 0x10, 0x10, 0x10, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x1F, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10,
    0x10, 0x10, 0x10, 0x10, 0x10, 0x1F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x10, 0x10, 0x10, 0x10, 0x10, 0xFF, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10,
    0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10,
    0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x10, 0x10, 0x10, 0x10, 0x10, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10,
    0x10, 0x10, 0x10, 0x10, 0x10, 0xF0, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10,
    0x10, 0x10, 0x10, 0x10, 0x10, 0x1F, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10,
    0x00, 0x72, 0x8A, 0x8A, 0x72, 0x02, 0x3E, 0x02, 0x3E, 0x20, 0x3E, 0x00,
    0x00, 0x72, 0x8A, 0x72, 0xFA, 0x2E, 0x42, 0x3E, 0x3E, 0x20, 0x3E, 0x00,
    0x00, 0x22, 0x22, 0xFA, 0x02, 0x72, 0x8B, 0x8A, 0x72, 0x22, 0xFA, 0x00,
    0x00, 0x10, 0x10, 0x28, 0x44, 0x82, 0x00, 0xFE, 0x10, 0x10, 0x10, 0x10,
    0x00, 0x7C, 0x44, 0x7C, 0x10, 0xFE, 0x00, 0x7C, 0x04, 0x04, 0x04, 0x00,
    0x00, 0x7C, 0x04, 0x04, 0x00, 0xFE, 0x00, 0x7C, 0x44, 0x44, 0x7C, 0x00,
    0x00, 0x7C, 0x40, 0x78, 0x40, 0x40, 0x7C, 0x10, 0x10, 0x10, 0xFE, 0x00,
    0x00, 0x82, 0x8E, 0x82, 0x8E, 0x82, 0xFA, 0x02, 0x40, 0x40, 0x7E, 0x00,
    0x00, 0x02, 0x22, 0x22, 0x22, 0x52, 0x52, 0x8A, 0x8A, 0x02, 0x02, 0x00,
    0x00, 0x44, 0x7C, 0x44, 0x7C, 0x00, 0xFE, 0x10, 0x50, 0x40, 0x7C, 0x00,
    0x00, 0x10, 0x10, 0xFE, 0x28, 0x44, 0x82, 0x10, 0x10, 0x10, 0xFE, 0x00,
    0x00, 0x01, 0x05, 0xF5, 0x15, 0x15, 0x17, 0x25, 0x45, 0x85, 0x05, 0x00,
    0x00, 0x01, 0x05, 0xF5, 0x85, 0x85, 0x87, 0x85, 0xF5, 0x05, 0x05, 0x00,
    0x00, 0x02, 0x72, 0x8A, 0x8A, 0x8A, 0x72, 0x02, 0x42, 0x40, 0x7E, 0x00,
    0x00, 0x00, 0x7C, 0x40, 0x40, 0x40, 0x7C, 0x10, 0x10, 0x10, 0xFE, 0x00,
    0x00, 0x02, 0x72, 0x8A, 0x72, 0xFA, 0x2E, 0x42, 0x22, 0x20, 0x3E, 0x00,

    0x00, 0x00, 0x00, 0x3E, 0x22, 0x3E, 0x22, 0x3E, 0x00, 0x00, 0x00,
    0x00, // 128
    0x00, 0x00, 0x3E, 0x22, 0x3E, 0x22, 0x3E, 0x22, 0x42, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x54, 0x54, 0x10, 0x28, 0x44, 0x82, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x12, 0xFC, 0x38, 0x34, 0x52, 0x91, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x10, 0xFE, 0x10, 0x38, 0x54, 0x92, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x28, 0x7C, 0x92, 0x7C, 0x54, 0xFE, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x10, 0x10, 0x7C, 0x10, 0x10, 0xFE, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x20, 0x7E, 0x80, 0x7C, 0x50, 0xFE, 0x10, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x08, 0xFC, 0xA8, 0xFE, 0xA4, 0xFE, 0x14, 0x04, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x28, 0x44, 0xFE, 0x14, 0x24, 0x48, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x74, 0x24, 0xF5, 0x65, 0xB2, 0xA4, 0x28, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x10, 0x10, 0x54, 0x92, 0x30, 0x10, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x10, 0xFE, 0x10, 0x28, 0x44, 0x82, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x10, 0x10, 0x10, 0x28, 0x44, 0x82, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x28, 0x7C, 0x82, 0x7C, 0x44, 0x7C, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x3C, 0x44, 0xA8, 0x10, 0x3E, 0xE2, 0x3E, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x08, 0x7F, 0x08, 0x7F, 0x08, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x06, 0x18, 0x20, 0x18, 0x06, 0x00, 0x3E, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x30, 0x0C, 0x02, 0x0C, 0x30, 0x00, 0x3E, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x08, 0x08, 0x3E, 0x08, 0x08, 0x00, 0x3E, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x22, 0x14, 0x08, 0x14, 0x22, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3E, 0x49, 0x7F, 0x49, 0x3E, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x08, 0x14, 0x22, 0x7F, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x7F, 0x22, 0x14, 0x08, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x22, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x08, 0x00, 0x08, 0x08, 0x08, 0x08, 0x08, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x22, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00,
    0x0C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x60,
    0x00, 0x0F, 0x08, 0x08, 0x08, 0x48, 0xA8, 0x18, 0x08, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x7E, 0x20, 0x10, 0x20, 0x7E, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x3E, 0x14, 0x14, 0x14, 0x14, 0x00, 0x00, 0x00, 0x00,

    0x00, 0x60, 0x90, 0x90, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, // 160
    0x00, 0x20, 0x60, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x60, 0x90, 0x20, 0x40, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x60, 0x90, 0x20, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x60, 0xA0, 0xA0, 0xF0, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0xF0, 0x80, 0xF0, 0x10, 0xE0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x60, 0x80, 0xF0, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0xF0, 0x10, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x60, 0x90, 0x60, 0x90, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x60, 0x90, 0xF0, 0x10, 0x60, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x02, 0x34, 0x48, 0x48, 0x36, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x18, 0x24, 0x38, 0x24, 0x24, 0x38, 0x20, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x4E, 0x30, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x18, 0x24, 0x24, 0x3C, 0x24, 0x24, 0x18, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x1C, 0x20, 0x20, 0x18, 0x24, 0x24, 0x18, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x08, 0x1C, 0x2A, 0x2A, 0x1C, 0x08, 0x00, 0x00, 0x00,
    0x80, 0x40, 0x40, 0x20, 0x10, 0x10, 0x08, 0x04, 0x04, 0x02, 0x01, 0x01,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFE, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x7C, 0x00, 0x00, 0xFE, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x7C, 0x00, 0x7C, 0x00, 0xFE, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0xFE, 0xAA, 0xAA, 0xAA, 0xFE, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x7C, 0x10, 0x7C, 0x14, 0x14, 0xFE, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x10, 0xFE, 0x00, 0x28, 0x44, 0x82, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x20, 0x20, 0x20, 0xFE, 0x20, 0x20, 0x3E, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x28, 0x44, 0x82, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x20, 0x20, 0xFC, 0x24, 0x24, 0x44, 0x86, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x36, 0x49, 0x36, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x18, 0x20, 0x18, 0x24, 0x18, 0x04, 0x18, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x08, 0x22, 0x14, 0x49, 0x14, 0x22, 0x08, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x38, 0x00, 0x7C, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00,
    0x00, 0x60, 0x90, 0x6E, 0x11, 0x10, 0x10, 0x11, 0x0E, 0x00, 0x00, 0x00,
    0x01, 0x02, 0x02, 0x04, 0x08, 0x08, 0x10, 0x20, 0x20, 0x40, 0x80, 0x80,

    0x00, 0x00, 0x20, 0x10, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, // 192
    0x00, 0x00, 0x00, 0x00, 0x3C, 0x02, 0x1E, 0x22, 0x1F, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x20, 0x20, 0x2C, 0x32, 0x22, 0x32, 0x2C, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x1C, 0x22, 0x20, 0x22, 0x1C, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x02, 0x02, 0x1A, 0x26, 0x22, 0x26, 0x1A, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x1C, 0x22, 0x3E, 0x20, 0x1E, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x0C, 0x10, 0x10, 0x7C, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x1A, 0x26, 0x22, 0x26, 0x1A, 0x02, 0x1C, 0x00,
    0x00, 0x00, 0x20, 0x20, 0x2C, 0x32, 0x22, 0x22, 0x22, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x08, 0x00, 0x18, 0x08, 0x08, 0x08, 0x1C, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x04, 0x00, 0x0C, 0x04, 0x04, 0x04, 0x24, 0x18, 0x00, 0x00,
    0x00, 0x00, 0x20, 0x20, 0x22, 0x24, 0x28, 0x34, 0x22, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x18, 0x08, 0x08, 0x08, 0x08, 0x08, 0x1C, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x76, 0x49, 0x49, 0x49, 0x49, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x2C, 0x32, 0x22, 0x22, 0x22, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x1C, 0x22, 0x22, 0x22, 0x1C, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x2C, 0x32, 0x22, 0x32, 0x2C, 0x20, 0x20, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x1A, 0x26, 0x22, 0x26, 0x1A, 0x02, 0x02, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x2E, 0x30, 0x20, 0x20, 0x20, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x1E, 0x20, 0x1C, 0x02, 0x3C, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x10, 0x38, 0x10, 0x10, 0x12, 0x0C, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x22, 0x22, 0x22, 0x26, 0x1A, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x22, 0x22, 0x22, 0x14, 0x08, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x49, 0x49, 0x49, 0x49, 0x36, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x22, 0x14, 0x08, 0x14, 0x22, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x22, 0x22, 0x22, 0x26, 0x1A, 0x02, 0x1C, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x3E, 0x04, 0x08, 0x10, 0x3E, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x08, 0x10, 0x10, 0x20, 0x10, 0x10, 0x08, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x54, 0xFE, 0x54, 0xFE, 0x54, 0x28, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0x08, 0x08, 0x04, 0x08, 0x08, 0x10, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x32, 0x4C, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x01, 0x3E, 0x54, 0x14, 0x14, 0x00, 0x00, 0x00,

    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, // 224
    0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
    0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
    0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0,
    0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0,
    0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
    0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
    0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0,
    0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0,
    0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
  ];
}
