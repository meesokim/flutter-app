/*
Copyright (c) 2012 Juan Mellado

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

/*
References:
- JSpeccy
  http://jspeccy.speccy.org/
*/

part of spc;

class Z80 {
  static const int _FLAG_C = 0x01;
  static const int _FLAG_N = 0x02;
  static const int _FLAG_P = 0x04;
  static const int _FLAG_V = 0x04;
  static const int _FLAG_3 = 0x08;
  static const int _FLAG_H = 0x10;
  static const int _FLAG_5 = 0x20;
  static const int _FLAG_Z = 0x40;
  static const int _FLAG_S = 0x80;

  static const int _FLAGS_53 = _FLAG_5 | _FLAG_3;
  static const int _FLAGS_SZ = _FLAG_S | _FLAG_Z;
  static const int _FLAGS_SZP = _FLAGS_SZ | _FLAG_P;
  static const int _FLAGS_SZHN = _FLAGS_SZ | _FLAG_H | _FLAG_N;
  static const int _FLAGS_SZHP = _FLAGS_SZP | _FLAG_H;
  static const int _FLAGS_SZHPC = _FLAGS_SZHP | _FLAG_C;

  final Machine _machine;

  int _a, _f, _b, _c, _d, _e, _h, _l;
  int _ax, _fx, _bx, _cx, _dx, _ex, _hx, _lx;
  int _ix, _iy, _sp, _pc, _i, _r, _memptr;
  int _im;
  bool _NMI, _INT, _EI, _HALT, _IFF1, _IFF2;

  final List<Function> _opcodes = new List<Function>(256);
  final List<Function> _opcodesCB = new List<Function>(256);
  final List<Function> _opcodesED = new List<Function>(256);
  final List<Function> _opcodesDDFD = new List<Function>(256);
  final List<Function> _opcodesDDFDCB = new List<Function>(256);

  final List<int> _sz53n_add = new List<int>(256);
  final List<int> _sz53n_sub = new List<int>(256);
  final List<int> _sz53pn_add = new List<int>(256);
  final List<int> _sz53pn_sub = new List<int>(256);

  Z80(this._machine) {
    _init();
  }

  int get _af => (_a << 8) | _f;
  int get _bc => (_b << 8) | _c;
  int get _de => (_d << 8) | _e;
  int get _hl => (_h << 8) | _l;
  int get _afx => (_ax << 8) | _fx;
  int get _bcx => (_bx << 8) | _cx;
  int get _dex => (_dx << 8) | _ex;
  int get _hlx => (_hx << 8) | _lx;
  int get _ir => (_i << 8) | _r;

  void set _af(int value) {
    _a = value >> 8;
    _f = value & 0xff;
  }
  void set _bc(int value) {
    _b = value >> 8;
    _c = value & 0xff;
  }
  void set _de(int value) {
    _d = value >> 8;
    _e = value & 0xff;
  }
  void set _hl(int value) {
    _h = value >> 8;
    _l = value & 0xff;
  }
  void set _afx(int value) {
    _ax = value >> 8;
    _fx = value & 0xff;
  }
  void set _bcx(int value) {
    _bx = value >> 8;
    _cx = value & 0xff;
  }
  void set _dex(int value) {
    _dx = value >> 8;
    _ex = value & 0xff;
  }
  void set _hlx(int value) {
    _hx = value >> 8;
    _lx = value & 0xff;
  }
  void set _ir(int value) {
    _i = value >> 8;
    _r = value & 0xff;
  }

  void set INT(bool value) {
    _INT = value;
  }

  void reset() {
    _af = _afx = _bc = _bcx = _de = _dex = _hl = _hlx = _ix = _iy = _sp = 0xffff;
    _pc = _ir = _im = 0;
    _NMI = _INT = _EI = _HALT = _IFF1 = _IFF2 = false;
    _memptr = 0xffff;
  }

  void run(int states) {
    while (_machine._frame.tstates < states) {

      if (_NMI) {
        _NMI = false;
        _nmi();

      } else {

        if (_INT) {
          if (_IFF1 && (!_EI)) {
            _interruption();
          }
        }

        _r = (_r & 0x80) | ((_r + 1) & 0x7f);

        var opcode = _machine.fetchOpcode(_pc);

        _pc = (_pc + 1) & 0xffff;

        _opcodes[opcode]();

        if (_EI && (opcode != 0xFB)) {
          _EI = false;
        }
      }
    }
  }

  void _nmi() {
    _machine.fetchOpcode(_pc);

    _machine._frame.tstates++;

    if (_HALT) {
      _HALT = false;
      _pc = (_pc + 1) & 0xffff;
    }

    _r = (_r & 0x80) | ((_r + 1) & 0x7f);

    _IFF1 = false;

    _push(_pc);

    _memptr = _pc = 0x0066;
  }

  void _interruption() {
    if (_HALT) {
      _HALT = false;
      _pc = (_pc + 1) & 0xffff;
    }

    _machine._frame.tstates += 7;

    _r = (_r & 0x80) | ((_r + 1) & 0x7f);

    _IFF1 = _IFF2 = false;

    _push(_pc);

    _memptr = _pc = _im == 2 ? _machine.peek16((_i << 8) | 0xff) : 0x0038;
  }

  int _rlc8(int value) {
    var cf = value >> 7;

    value = ((value << 1) & 0xfe) | cf;

    _f = _sz53pn_add[value] | cf;

    return value;
  }

  int _rl8(int value) {
    var cf = value >> 7;

    value = ((value << 1) & 0xfe) | (_f & _FLAG_C);

    _f = _sz53pn_add[value] | cf;

    return value;
  }

  int _sla8(int value) {
    var cf = value >> 7;

    value = (value << 1) & 0xfe;

    _f = _sz53pn_add[value] | cf;

    return value;
  }

  int _sll8(int value) {
    var cf = value >> 7;

    value = ((value << 1) & 0xfe) | 0x01;

    _f = _sz53pn_add[value] | cf;

    return value;
  }

  int _rrc8(int value) {
    var cf = value & 0x01;

    value = (value >> 1) | (cf << 7);

    _f = _sz53pn_add[value] | cf;

    return value;
  }

  int _rr8(int value) {
    var cf = value & 0x01;

    value = (value >> 1) | ((_f & _FLAG_C) << 7);

    _f = _sz53pn_add[value] | cf;

    return value;
  }

  void _rrd() {
    var high = (_a & 0x0f) << 4;

    var low = _machine.peek8(_hl);

    _a = (_a & 0xf0) | (low & 0x0f);

    _machine.contention(_hl, 4);

    _machine.poke8(_hl, high | (low >> 4));

    _f = _sz53pn_add[_a] | (_f & _FLAG_C);

    _memptr = (_hl + 1) & 0xffff;
  }

  void _rld() {
    var low = _a & 0x0f;

    var high = _machine.peek8(_hl);

    _a = (_a & 0xf0) | (high >> 4);

    _machine.contention(_hl, 4);

    _machine.poke8(_hl, ((high << 4) & 0xff) | low);

    _f = _sz53pn_add[_a] | (_f & _FLAG_C);

    _memptr = (_hl + 1) & 0xffff;
  }

  int _sra8(int value) {
    var cf = value & 0x01;

    value = (value & 0x80) | (value >> 1);

    _f = _sz53pn_add[value] | cf;

    return value;
  }

  int _srl8(int value) {
    var cf = value & 0x01;

    value >>= 1;

    _f = _sz53pn_add[value] | cf;

    return value;
  }

  int _inc8(int value) {
    value = (value + 1) & 0xff;

    _f = _sz53n_add[value] | (_f & _FLAG_C);

    if ((value & 0x0f) == 0) {
      _f |= _FLAG_H;
    }

    if (value == 0x80) {
      _f |= _FLAG_V;
    }

    return value;
  }

  int _dec8(int value) {
    value = (value - 1) & 0xff;

    _f = _sz53n_sub[value] | (_f & _FLAG_C);

    if ((value & 0x0f) == 0x0f) {
      _f |= _FLAG_H;
    }

    if (value == 0x7f) {
      _f |= _FLAG_V;
    }

    return value;
  }

  void _addA(int value) {
    var sum = _a + value;

    var cf = sum > 0xff ? _FLAG_C : 0;

    sum &= 0xff;

    _f = _sz53n_add[sum] | cf;

    if ((sum & 0x0f) < (_a & 0x0f)) {
      _f |= _FLAG_H;
    }

    if (((_a ^ (value ^ 0xff)) & (_a ^ sum)) > 0x7f) {
      _f |= _FLAG_V;
    }

    _a = sum;
  }

  void _adcA(int value) {
    var sum = _a + value + (_f & _FLAG_C);

    var cf = sum > 0xff ? _FLAG_C : 0;

    sum &= 0xff;

    _f = _sz53n_add[sum] | cf;

    if (((_a ^ value ^ sum) & 0x10) != 0) {
      _f |= _FLAG_H;
    }

    if (((_a ^ (value ^ 0xff)) & (_a ^ sum)) > 0x7f) {
      _f |= _FLAG_V;
    }

    _a = sum;
  }

  int _add16(int register, int value) {
    _memptr = (register + 1) & 0xffff;

    value += register;

    _f = (_f & _FLAGS_SZP) | ((value >> 8) & _FLAGS_53) | (value > 0xffff ? _FLAG_C : 0);

    value &= 0xffff;

    if ((value & 0x0fff) < (register & 0x0fff)) {
      _f |= _FLAG_H;
    }

    return value;
  }

  void _adcHL(int value) {
    var register = _hl;

    _memptr = (register + 1) & 0xffff;

    var sum = register + value + (_f & _FLAG_C);

    var cf = sum > 0xffff ? _FLAG_C : 0;

    _hl = (sum &= 0xffff);

    _f = _sz53n_add[_h] | cf;

    if (sum != 0) {
      _f &= _FLAG_Z ^ 0xff;
    }

    if (((sum ^ register ^ value) & 0x1000) != 0) {
      _f |= _FLAG_H;
    }

    if (((register ^ (value ^ 0xff)) & (register ^ value)) > 0x7fff) {
      _f |= _FLAG_V;
    }
  }

  void _subA(int value) {
    var sub = _a - value;

    var cf = sub < 0 ? _FLAG_C : 0;

    sub &= 0xff;

    _f = _sz53n_sub[sub] | cf;

    if ((sub & 0x0f) > (_a & 0x0f)) {
      _f |= _FLAG_H;
    }

    if (((_a ^ value) & (_a ^ sub)) > 0x7f) {
      _f |= _FLAG_V;
    }

    _a = sub;
  }

  void _sbcA(int value) {
    var sub = _a - value - (_f & _FLAG_C);

    var cf = sub < 0 ? _FLAG_C : 0;

    sub &= 0xff;

    _f = _sz53n_sub[sub] | cf;

    if (((_a ^ value ^ sub) & 0x10) != 0) {
      _f |= _FLAG_H;
    }

    if (((_a ^ value) & (_a ^ sub)) > 0x7f) {
      _f |= _FLAG_V;
    }

    _a = sub;
  }

  void _sbcHL(int value) {
    var register = _hl;

    _memptr = (register + 1) & 0xffff;

    var sub = register - value - (_f & _FLAG_C);

    var cf = sub < 0 ? _FLAG_C : 0;

    _hl = (sub &= 0xffff);

    _f = _sz53n_sub[_h] | cf;

    if (sub != 0) {
      _f &= _FLAG_Z ^ 0xff;
    }

    if (((sub ^ register ^ value) & 0x1000) != 0) {
      _f |= _FLAG_H;
    }

    if (((register ^ value) & (register ^ sub)) > 0x7fff) {
      _f |= _FLAG_V;
    }
  }

  void _andA(int value) {
    _a &= value;

    _f = _sz53pn_add[_a] | _FLAG_H;
  }

  void _xorA(int value) {
    _a ^= value;

    _f = _sz53pn_add[_a];
  }

  void _orA(int value) {
    _a |= value;

    _f = _sz53pn_add[_a];
  }

  void _cp(int value) {
    var cmp = _a - value;

    var cf = cmp < 0 ? _FLAG_C : 0;

    cmp &= 0xff;

    _f = (_sz53n_sub[cmp] & _FLAGS_SZHN) | (_sz53n_add[value] & _FLAGS_53) | cf;

    if ((cmp & 0x0f) > (_a & 0x0f)) {
      _f |= _FLAG_H;
    }

    if (((_a ^ value) & (_a ^ cmp)) > 0x7f) {
      _f |= _FLAG_V;
    }
  }

  void _daa() {
    var value = 0;

    var cf = _f & _FLAG_C;

    if (((_f & _FLAG_H) != 0) || ((_a & 0x0f) > 0x09)) {
      value = 0x06;
    }

    if ((cf != 0) || (_a > 0x99)) {
      value |= 0x60;
    }

    if (_a > 0x99) {
      cf = _FLAG_C;
    }

    if ((_f & _FLAG_N) != 0) {
      _subA(value);
      _f = _sz53pn_sub[_a] | (_f & _FLAG_H) | cf;
    } else {
      _addA(value);
      _f = _sz53pn_add[_a] | (_f & _FLAG_H) | cf;
    }
  }

  int _pop() {
    var value = _machine.peek16(_sp);

    _sp = (_sp + 2) & 0xffff;

    return value;
  }

  void _push(int value) {
    _sp = (_sp - 1) & 0xffff;
    _machine.poke8(_sp, value >> 8);

    _sp = (_sp - 1) & 0xffff;
    _machine.poke8(_sp, value & 0xff);
  }

  void _ldi() {
    var value = _machine.peek8(_hl);

    _machine.poke8(_de, value);

    _machine.contention(_de, 2);

    _hl = (_hl + 1) & 0xffff;
    _de = (_de + 1) & 0xffff;
    _bc = (_bc - 1) & 0xffff;

    value += _a;

    _f = (_f & _FLAGS_SZ) | (value & _FLAG_3) | (_f & _FLAG_C);

    if ((value & _FLAG_N) != 0) {
      _f |= _FLAG_5;
    }

    if (_bc != 0) {
      _f |= _FLAG_P;
    }
  }

  void _ldd() {
    var value = _machine.peek8(_hl);

    _machine.poke8(_de, value);

    _machine.contention(_de, 2);

    _hl = (_hl - 1) & 0xffff;
    _de = (_de - 1) & 0xffff;
    _bc = (_bc - 1) & 0xffff;

    value += _a;

    _f = (_f & _FLAGS_SZ) | (value & _FLAG_3) | (_f & _FLAG_C);

    if ((value & _FLAG_N) != 0) {
      _f |= _FLAG_5;
    }

    if (_bc != 0) {
      _f |= _FLAG_P;
    }
  }

  void _cpi() {
    var value = _machine.peek8(_hl);

    var cf = _f & _FLAG_C;

    _cp(value);

    _machine.contention(_hl, 5);

    _hl = (_hl + 1) & 0xffff;
    _bc = (_bc - 1) & 0xffff;

    value = _a - value - ((_f & _FLAG_H) != 0 ? 1 : 0);

    _f = (_f & _FLAGS_SZHN) | (value & _FLAG_3) | cf;

    if ((value & _FLAG_N) != 0) {
      _f |= _FLAG_5;
    }

    if (_bc != 0) {
      _f |= _FLAG_P;
    }

    _memptr = (_memptr + 1) & 0xffff;
  }

  void _cpd() {
    var value = _machine.peek8(_hl);

    var cf = _f & _FLAG_C;

    _cp(value);

    _machine.contention(_hl, 5);

    _hl = (_hl - 1) & 0xffff;
    _bc = (_bc - 1) & 0xffff;

    value = _a - value - ((_f & _FLAG_H) != 0 ? 1 : 0);

    _f = (_f & _FLAGS_SZHN) | (value & _FLAG_3) | cf;

    if ((value & _FLAG_N) != 0) {
      _f |= _FLAG_5;
    }

    if (_bc != 0) {
      _f |= _FLAG_P;
    }

    _memptr = (_memptr - 1) & 0xffff;
  }

  void _ini() {
    _memptr = (_bc + 1) & 0xffff;

    _machine.contention(_ir, 1);

    var value = _machine.in8(_bc);

    _machine.poke8(_hl, value);

    _b = (_b - 1) & 0xff;
    _hl = (_hl + 1) & 0xffff;

    _f = _sz53pn_add[_b];

    if (value > 0x7f) {
      _f |= _FLAG_N;
    }

    value += (_c + 1) & 0xff;

    if (value > 0xff) {
      _f |= _FLAG_H | _FLAG_C;
    }

    if ((_sz53pn_add[(value & 0x07) ^ _b] & _FLAG_P) != 0) {
      _f |= _FLAG_P;
    } else {
      _f &= _FLAG_P ^ 0xff;
    }
  }

  void _ind() {
    _memptr = (_bc - 1) & 0xffff;

    _machine.contention(_ir, 1);

    var value = _machine.in8(_bc);

    _machine.poke8(_hl, value);

    _b = (_b - 1) & 0xff;
    _hl = (_hl - 1) & 0xffff;

    _f = _sz53pn_add[_b];

    if (value > 0x7f) {
      _f |= _FLAG_N;
    }

    value += (_c - 1) & 0xff;

    if (value > 0xff) {
      _f |= _FLAG_H | _FLAG_C;
    }

    if ((_sz53pn_add[(value & 0x07) ^ _b] & _FLAG_P) != 0) {
      _f |= _FLAG_P;
    } else {
      _f &= _FLAG_P ^ 0xff;
    }
  }

  void _outi() {
    _machine.contention(_ir, 1);

    _b = (_b - 1) & 0xff;

    _memptr = (_bc + 1) & 0xffff;

    int value = _machine.peek8(_hl);

    _machine.out8(_bc, value);

    _hl = (_hl + 1) & 0xffff;

    _f = value > 0x7f ? _sz53n_sub[_b] : _sz53n_add[_b];

    if ((_l + value) > 0xff) {
      _f |= _FLAG_H | _FLAG_C;
    }

    if ((_sz53pn_add[((_l + value) & 0x07) ^ _b] & _FLAG_P) != 0) {
      _f |= _FLAG_P;
    }
  }

  void _outd() {
    _machine.contention(_ir, 1);

    _b = (_b - 1) & 0xff;

    _memptr = (_bc - 1) & 0xffff;

    int value = _machine.peek8(_hl);

    _machine.out8(_bc, value);

    _hl = (_hl - 1) & 0xffff;

    _f = value > 0x7f ? _sz53n_sub[_b] : _sz53n_add[_b];

    if ((_l + value) > 0xff) {
      _f |= _FLAG_H | _FLAG_C;
    }

    if ((_sz53pn_add[((_l + value) & 0x07) ^ _b] & _FLAG_P) != 0) {
      _f |= _FLAG_P;
    }
  }

  void _bit(int mask, int value) {
    var zf = (mask & value) == 0;

    _f = (_sz53n_add[value] & (_FLAGS_SZP ^ 0xff)) | _FLAG_H | (_f & _FLAG_C);

    if (zf) {
      _f |= _FLAG_P | _FLAG_Z;
    }

    if ((mask == 0x80) && !zf) {
      _f |= _FLAG_S;
    }
  }

  void _rlca() {
    var cf = (_a & 0x80) != 0 ? _FLAG_C : 0;

    _a = ((_a << 1) & 0xfe) | cf;

    _f = (_f & _FLAGS_SZP) | (_a & _FLAGS_53) | cf;
  }

  void _rrca() {
    var cf = _a & 0x01;

    _a = (_a >> 1) | (cf << 7);

    _f = (_f & _FLAGS_SZP) | (_a & _FLAGS_53) | cf;
  }

  void _rla() {
    var cf = (_a & 0x80) != 0 ? _FLAG_C : 0;

    _a = ((_a << 1) & 0xfe) | (_f & _FLAG_C);

    _f = (_f & _FLAGS_SZP) | (_a & _FLAGS_53) | cf;
  }

  void _rra() {
    var cf = _a & 0x01;

    _a = (_a >> 1) | ((_f & _FLAG_C) << 7);

    _f = (_f & _FLAGS_SZP) | (_a & _FLAGS_53) | cf;
  }

  void _init() {
    _initOpcodes();
    _initOpcodesCB();
    _initOpcodesED();
    _initOpcodesDDFD();
    _initOpcodesDDFDCB();
    _initFlags();
  }

  void _initOpcodes() {

    _opcodes[0x00] = () { //NOP
    };

    _opcodes[0x01] = () { //LD BC, nn
      _bc = _machine.peek16(_pc);
      _pc = (_pc + 2) & 0xffff;
    };

    _opcodes[0x02] = () { //LD (BC), A
      _machine.poke8(_bc, _a);
      _memptr = (_a << 8) | ((_c + 1) & 0xff);
    };

    _opcodes[0x03] = () { //INC BC
      _machine.contention(_ir, 2);
      _bc = (_bc + 1) & 0xffff;
    };

    _opcodes[0x04] = () { //INC B
      _b = _inc8(_b);
    };

    _opcodes[0x05] = () { //DEC B
      _b = _dec8(_b);
    };

    _opcodes[0x06] = () { //LD B, N
      _b = _machine.peek8(_pc);
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0x07] = () { //RLCA
      _rlca();
    };

    _opcodes[0x08] = () { //EX AF, AF'
      var value = _af;
      _af = _afx;
      _afx = value;
    };

    _opcodes[0x09] = () { //ADD HL, BC
      _machine.contention(_ir, 7);
      _hl = _add16(_hl, _bc);
    };

    _opcodes[0x0A] = () { //LD A, (BC)
      _memptr = _bc;
      _a = _machine.peek8(_memptr);
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodes[0x0B] = () { //DEC BC
      _machine.contention(_ir, 2);
      _bc = (_bc - 1) & 0xffff;
    };

    _opcodes[0x0C] = () { //INC C
      _c = _inc8(_c);
    };

    _opcodes[0x0D] = () { //DEC C
      _c = _dec8(_c);
    };

    _opcodes[0x0E] = () { //LD C, n
      _c = _machine.peek8(_pc);
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0x0F] = () { //RRCA
      _rrca();
    };

    _opcodes[0x10] = () { //DJNZ offset
      _machine.contention(_ir, 1);
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _b = (_b - 1) & 0xff;
      if (_b != 0) {
        _machine.contention(_pc, 5);
        _memptr = _pc = (_pc + value + 1) & 0xffff;
      } else {
        _pc = (_pc + 1) & 0xffff;
      }
    };

    _opcodes[0x11] = () { //LD DE, nn
      _de = _machine.peek16(_pc);
      _pc = (_pc + 2) & 0xffff;
    };

    _opcodes[0x12] = () { //LD (DE), A
      _machine.poke8(_de, _a);
      _memptr = (_a << 8) | ((_e + 1) & 0xff);
    };

    _opcodes[0x13] = () { //INC DE
      _machine.contention(_ir, 2);
      _de = (_de + 1) & 0xffff;
    };

    _opcodes[0x14] = () { //INC D
      _d = _inc8(_d);
    };

    _opcodes[0x15] = () { //DEC D
      _d = _dec8(_d);
    };

    _opcodes[0x16] = () { //LD D, n
      _d = _machine.peek8(_pc);
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0x17] = () { //RLA
      _rla();
    };

    _opcodes[0x18] = () { //JR offset
      _memptr = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _machine.contention(_pc, 5);
      _memptr = _pc = (_pc + _memptr + 1) & 0xffff;
    };

    _opcodes[0x19] = () { //ADD HL, DE
      _machine.contention(_ir, 7);
      _hl = _add16(_hl, _de);
    };

    _opcodes[0x1A] = () { //LD A, (DE)
      _memptr = _de;
      _a = _machine.peek8(_memptr);
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodes[0x1B] = () { //DEC DE
      _machine.contention(_ir, 2);
      _de = (_de - 1) & 0xffff;
    };

    _opcodes[0x1C] = () { //INC E
      _e = _inc8(_e);
    };

    _opcodes[0x1D] = () { //DEC E
      _e = _dec8(_e);
    };

    _opcodes[0x1E] = () { //LD E, n
      _e = _machine.peek8(_pc);
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0x1F] = () { //RRA
      _rra();
    };

    _opcodes[0x20] = () { //JR NZ, offset
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      if ((_f & _FLAG_Z) == 0) {
        _machine.contention(_pc, 5);
        _pc = (_pc + value + 1) & 0xffff;
      } else {
        _pc = (_pc + 1) & 0xffff;
      }
    };

    _opcodes[0x21] = () { //LD HL, nn
      _hl = _machine.peek16(_pc);
      _pc = (_pc + 2) & 0xffff;
    };

    _opcodes[0x22] = () { //LD (nn), HL
      _memptr = _machine.peek16(_pc);
      _machine.poke16(_memptr, _hl);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodes[0x23] = () { //INC HL
      _machine.contention(_ir, 2);
      _hl = (_hl + 1) & 0xffff;
    };

    _opcodes[0x24] = () { //INC H
      _h = _inc8(_h);
    };

    _opcodes[0x25] = () { //DEC H
      _h = _dec8(_h);
    };

    _opcodes[0x26] = () { //LD H, n
      _h = _machine.peek8(_pc);
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0x27] = () { //DAA
      _daa();
    };

    _opcodes[0x28] = () { //JR Z, offset
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      if ((_f & _FLAG_Z) != 0) {
        _machine.contention(_pc, 5);
        _pc = (_pc + value + 1) & 0xffff;
      } else {
        _pc = (_pc + 1) & 0xffff;
      }
    };

    _opcodes[0x29] = () { //ADD HL, HL
      _machine.contention(_ir, 7);
      var value = _hl;
      _hl = _add16(value, value);
    };

    _opcodes[0x2A] = () { //LD HL, (nn)
      _memptr = _machine.peek16(_pc);
      _hl = _machine.peek16(_memptr);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodes[0x2B] = () { //DEC HL
      _machine.contention(_ir, 2);
      _hl = (_hl - 1) & 0xffff;
    };

    _opcodes[0x2C] = () { //INC L
      _l = _inc8(_l);
    };

    _opcodes[0x2D] = () { //DEC L
      _l = _dec8(_l);
    };

    _opcodes[0x2E] = () { //LD L, n
      _l = _machine.peek8(_pc);
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0x2F] = () { //CPL
      _a ^= 0xff;
      _f = (_f & _FLAGS_SZP) | _FLAG_H | (_a & _FLAGS_53) | _FLAG_N | (_f & _FLAG_C);
    };

    _opcodes[0x30] = () { //JR NC, offset
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      if ((_f & _FLAG_C) == 0) {
        _machine.contention(_pc, 5);
        _pc = (_pc + value + 1) & 0xffff;
      } else {
        _pc = (_pc + 1) & 0xffff;
      }
    };

    _opcodes[0x31] = () { //LD SP, nn
      _sp = _machine.peek16(_pc);
      _pc = (_pc + 2) & 0xffff;
    };

    _opcodes[0x32] = () { //LD (nn), A
      _memptr = _machine.peek16(_pc);
      _machine.poke8(_memptr, _a);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_a << 8) | ((_memptr + 1) & 0xffff);
    };

    _opcodes[0x33] = () { //INC SP
      _machine.contention(_ir, 2);
      _sp = (_sp + 1) & 0xffff;
    };

    _opcodes[0x34] = () { //INC (HL)
      var value = _inc8(_machine.peek8(_hl));
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodes[0x35] = () { //DEC (HL)
      var value = _dec8(_machine.peek8(_hl));
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodes[0x36] = () { //LD (HL), n
      _machine.poke8(_hl, _machine.peek8(_pc));
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0x37] = () { //SCF
      _f = (_f & _FLAGS_SZP) | (_a & _FLAGS_53) | _FLAG_C;
    };

    _opcodes[0x38] = () { //JR C, offset
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      if ((_f & _FLAG_C) != 0) {
        _machine.contention(_pc, 5);
        _pc = (_pc + value + 1) & 0xffff;
      } else {
        _pc = (_pc + 1) & 0xffff;
      }
    };

    _opcodes[0x39] = () { //ADD HL, SP
      _machine.contention(_ir, 7);
      _hl = _add16(_hl, _sp);
    };

    _opcodes[0x3A] = () { //LD A, (nn)
      _memptr = _machine.peek16(_pc);
      _a = _machine.peek8(_memptr);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodes[0x3B] = () { //DEC SP
      _machine.contention(_ir, 2);
      _sp = (_sp - 1) & 0xffff;
    };

    _opcodes[0x3C] = () { //INC A
      _a = _inc8(_a);
    };

    _opcodes[0x3D] = () { //DEC A
      _a = _dec8(_a);
    };

    _opcodes[0x3E] = () { //LD A, n
      _a = _machine.peek8(_pc);
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0x3F] = () { //CCF
      _f = (_f & _FLAGS_SZP) | (_a & _FLAGS_53) | ((_f & _FLAG_C) != 0 ? _FLAG_H : _FLAG_C);
    };

    _opcodes[0x40] = () { //LD B, B
    };

    _opcodes[0x41] = () { //LD B, C
      _b = _c;
    };

    _opcodes[0x42] = () { //LD B, D
      _b = _d;
    };

    _opcodes[0x43] = () { //LD B, E
      _b = _e;
    };

    _opcodes[0x44] = () { //LD B, H
      _b = _h;
    };

    _opcodes[0x45] = () { //LD B, L
      _b = _l;
    };

    _opcodes[0x46] = () { //LD B, (HL)
      _b = _machine.peek8(_hl);
    };

    _opcodes[0x47] = () { //LD B, A
      _b = _a;
    };

    _opcodes[0x48] = () { //LD C, B
      _c = _b;
    };

    _opcodes[0x49] = () { //LD C, C
    };

    _opcodes[0x4A] = () { //LD C, D
      _c = _d;
    };

    _opcodes[0x4B] = () { //LD C, E
      _c = _e;
    };

    _opcodes[0x4C] = () { //LD C, H
      _c = _h;
    };

    _opcodes[0x4D] = () { //LD C, L
      _c = _l;
    };

    _opcodes[0x4E] = () { //LD C, (HL)
      _c = _machine.peek8(_hl);
    };

    _opcodes[0x4F] = () { //LD C, A
      _c = _a;
    };

    _opcodes[0x50] = () { //LD D, B
      _d = _b;
    };

    _opcodes[0x51] = () { //LD D, C
      _d = _c;
    };

    _opcodes[0x52] = () { //LD D, D
    };

    _opcodes[0x53] = () { //LD D, E
      _d = _e;
    };

    _opcodes[0x54] = () { //LD D, H
      _d = _h;
    };

    _opcodes[0x55] = () { //LD D, L
      _d = _l;
    };

    _opcodes[0x56] = () { //LD D, (HL)
      _d = _machine.peek8(_hl);
    };

    _opcodes[0x57] = () { //LD D, A
      _d = _a;
    };

    _opcodes[0x58] = () { //LD E, B
      _e = _b;
    };

    _opcodes[0x59] = () { //LD E, C
      _e = _c;
    };

    _opcodes[0x5A] = () { //LD E, D
      _e = _d;
    };

    _opcodes[0x5B] = () { //LD E, E
    };

    _opcodes[0x5C] = () { //LD E, H
      _e = _h;
    };

    _opcodes[0x5D] = () { //LD E, L
      _e = _l;
    };

    _opcodes[0x5E] = () { //LD E, (HL)
      _e = _machine.peek8(_hl);
    };

    _opcodes[0x5F] = () { //LD E, A
      _e = _a;
    };

    _opcodes[0x60] = () { //LD H, B
      _h = _b;
    };

    _opcodes[0x61] = () { //LD H, C
      _h = _c;
    };

    _opcodes[0x62] = () { //LD H, D
      _h = _d;
    };

    _opcodes[0x63] = () { //LD H, E
      _h = _e;
    };

    _opcodes[0x64] = () { //LD H, H
    };

    _opcodes[0x65] = () { //LD H, L
      _h = _l;
    };

    _opcodes[0x66] = () { //LD H, (HL)
      _h = _machine.peek8(_hl);
    };

    _opcodes[0x67] = () { //LD H, A
      _h = _a;
    };

    _opcodes[0x68] = () { //LD L, B
      _l = _b;
    };

    _opcodes[0x69] = () { //LD L, C
      _l = _c;
    };

    _opcodes[0x6A] = () { //LD L, D
      _l = _d;
    };

    _opcodes[0x6B] = () { //LD L, E
      _l = _e;
    };

    _opcodes[0x6C] = () { //LD L, H
      _l = _h;
    };

    _opcodes[0x6D] = () { //LD L, L
    };

    _opcodes[0x6E] = () { //LD L, (HL)
      _l = _machine.peek8(_hl);
    };

    _opcodes[0x6F] = () { //LD L, A
      _l = _a;
    };

    _opcodes[0x70] = () { //LD (HL), B
      _machine.poke8(_hl, _b);
    };

    _opcodes[0x71] = () { //LD (HL), C
      _machine.poke8(_hl, _c);
    };

    _opcodes[0x72] = () { //LD (HL), D
      _machine.poke8(_hl, _d);
    };

    _opcodes[0x73] = () { //LD (HL), E
      _machine.poke8(_hl, _e);
    };

    _opcodes[0x74] = () { //LD (HL), H
      _machine.poke8(_hl, _h);
    };

    _opcodes[0x75] = () { //LD (HL), L
      _machine.poke8(_hl, _l);
    };

    _opcodes[0x76] = () { //HALT
      _pc = (_pc - 1) & 0xffff;
      _HALT = true;
    };

    _opcodes[0x77] = () { //LD (HL), A
      _machine.poke8(_hl, _a);
    };

    _opcodes[0x78] = () { //LD A, B
      _a = _b;
    };

    _opcodes[0x79] = () { //LD A, C
      _a = _c;
    };

    _opcodes[0x7A] = () { //LD A, D
      _a = _d;
    };

    _opcodes[0x7B] = () { //LD A, E
      _a = _e;
    };

    _opcodes[0x7C] = () { //LD A, H
      _a = _h;
    };

    _opcodes[0x7D] = () { //LD A, L
      _a = _l;
    };

    _opcodes[0x7E] = () { //LD A, (HL)
      _a = _machine.peek8(_hl);
    };

    _opcodes[0x7F] = () { //LD A, A
    };

    _opcodes[0x80] = () { //ADD A, B
      _addA(_b);
    };

    _opcodes[0x81] = () { //ADD A, C
      _addA(_c);
    };

    _opcodes[0x82] = () { //ADD A, D
      _addA(_d);
    };

    _opcodes[0x83] = () { //ADD A, E
      _addA(_e);
    };

    _opcodes[0x84] = () { //ADD A, H
      _addA(_h);
    };

    _opcodes[0x85] = () { //ADD A, L
      _addA(_l);
    };

    _opcodes[0x86] = () { //ADD A, (HL)
      _addA(_machine.peek8(_hl));
    };

    _opcodes[0x87] = () { //ADD A, A
      _addA(_a);
    };

    _opcodes[0x88] = () { //ADC A, B
      _adcA(_b);
    };

    _opcodes[0x89] = () { //ADC A, C
      _adcA(_c);
    };

    _opcodes[0x8A] = () { //ADC A, D
      _adcA(_d);
    };

    _opcodes[0x8B] = () { //ADC A, E
      _adcA(_e);
    };

    _opcodes[0x8C] = () { //ADC A, H
      _adcA(_h);
    };

    _opcodes[0x8D] = () { //ADC A, L
      _adcA(_l);
    };

    _opcodes[0x8E] = () { //ADC A, (HL)
      _adcA(_machine.peek8(_hl));
    };

    _opcodes[0x8F] = () { //ADC A, A
      _adcA(_a);
    };

    _opcodes[0x90] = () { //SUB B
      _subA(_b);
    };

    _opcodes[0x91] = () { //SUB C
      _subA(_c);
    };

    _opcodes[0x92] = () { //SUB D
      _subA(_d);
    };

    _opcodes[0x93] = () { //SUB E
      _subA(_e);
    };

    _opcodes[0x94] = () { //SUB H
      _subA(_h);
    };

    _opcodes[0x95] = () { //SUB L
      _subA(_l);
    };

    _opcodes[0x96] = () { //SUB (HL)
      _subA(_machine.peek8(_hl));
    };

    _opcodes[0x97] = () { //SUB A
      _subA(_a);
    };

    _opcodes[0x98] = () { //SBC A, B
      _sbcA(_b);
    };

    _opcodes[0x99] = () { //SBC A, C
      _sbcA(_c);
    };

    _opcodes[0x9A] = () { //SBC A, D
      _sbcA(_d);
    };

    _opcodes[0x9B] = () { //SBC A, E
      _sbcA(_e);
    };

    _opcodes[0x9C] = () { //SBC A, H
      _sbcA(_h);
    };

    _opcodes[0x9D] = () { //SBC A, L
      _sbcA(_l);
    };

    _opcodes[0x9E] = () { //SBC A, (HL)
      _sbcA(_machine.peek8(_hl));
    };

    _opcodes[0x9F] = () { //SBC A, A
      _sbcA(_a);
    };

    _opcodes[0xA0] = () { //AND B
      _andA(_b);
    };

    _opcodes[0xA1] = () { //AND C
      _andA(_c);
    };

    _opcodes[0xA2] = () { //AND D
      _andA(_d);
    };

    _opcodes[0xA3] = () { //AND E
      _andA(_e);
    };

    _opcodes[0xA4] = () { //AND H
      _andA(_h);
    };

    _opcodes[0xA5] = () { //AND L
      _andA(_l);
    };

    _opcodes[0xA6] = () { //AND (HL)
      _andA(_machine.peek8(_hl));
    };

    _opcodes[0xA7] = () { //AND A
      _andA(_a);
    };

    _opcodes[0xA8] = () { //XOR B
      _xorA(_b);
    };

    _opcodes[0xA9] = () { //XOR C
      _xorA(_c);
    };

    _opcodes[0xAA] = () { //XOR D
      _xorA(_d);
    };

    _opcodes[0xAB] = () { //XOR E
      _xorA(_e);
    };

    _opcodes[0xAC] = () { //XOR H
      _xorA(_h);
    };

    _opcodes[0xAD] = () { //XOR L
      _xorA(_l);
    };

    _opcodes[0xAE] = () { //XOR (HL)
      _xorA(_machine.peek8(_hl));
    };

    _opcodes[0xAF] = () { //XOR A
      _xorA(_a);
    };

    _opcodes[0xB0] = () { //OR B
      _orA(_b);
    };

    _opcodes[0xB1] = () { //OR C
      _orA(_c);
    };

    _opcodes[0xB2] = () { //OR D
      _orA(_d);
    };

    _opcodes[0xB3] = () { //OR E
      _orA(_e);
    };

    _opcodes[0xB4] = () { //OR H
      _orA(_h);
    };

    _opcodes[0xB5] = () { //OR L
      _orA(_l);
    };

    _opcodes[0xB6] = () { //OR (HL)
      _orA(_machine.peek8(_hl));
    };

    _opcodes[0xB7] = () { //OR A
      _orA(_a);
    };

    _opcodes[0xB8] = () { //CP B
      _cp(_b);
    };

    _opcodes[0xB9] = () { //CP C
      _cp(_c);
    };

    _opcodes[0xBA] = () { //CP D
      _cp(_d);
    };

    _opcodes[0xBB] = () { //CP E
      _cp(_e);
    };

    _opcodes[0xBC] = () { //CP H
      _cp(_h);
    };

    _opcodes[0xBD] = () { //CP L
      _cp(_l);
    };

    _opcodes[0xBE] = () { //CP (HL)
      _cp(_machine.peek8(_hl));
    };

    _opcodes[0xBF] = () { //CP A
      _cp(_a);
    };

    _opcodes[0xC0] = () { //RET NZ
      _machine.contention(_ir, 1);
      if ((_f & _FLAG_Z) == 0) {
        _memptr = _pc = _pop();
      }
    };

    _opcodes[0xC1] = () { //POP BC
      _bc = _pop();
    };

    _opcodes[0xC2] = () { //JP NZ, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_Z) == 0) {
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xC3] = () { //JP nn
      _memptr = _pc = _machine.peek16(_pc);
    };

    _opcodes[0xC4] = () { //CALL NZ, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_Z) == 0) {
        _machine.contention((_pc + 1) & 0xffff, 1);
        _push((_pc + 2) & 0xffff);
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xC5] = () { //PUSH BC
      _machine.contention(_ir, 1);
      _push(_bc);
    };

    _opcodes[0xC6] = () { //ADD A, n
      _addA(_machine.peek8(_pc));
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0xC7] = () { //RST 0
      _machine.contention(_ir, 1);
      _push(_pc);
      _memptr = _pc = 0x0000;
    };

    _opcodes[0xC8] = () { //RET Z
      _machine.contention(_ir, 1);
      if ((_f & _FLAG_Z) != 0) {
        _memptr = _pc = _pop();
      }
    };

    _opcodes[0xC9] = () { //RET
      _memptr = _pc = _pop();
    };

    _opcodes[0xCA] = () { //JP Z, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_Z) != 0) {
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xCB] = () { //CB prefix
      _r = (_r & 0x80) | ((_r + 1) & 0x7f);
      var opcode = _machine.fetchOpcode(_pc);
      _pc = (_pc + 1) & 0xffff;

      _opcodesCB[opcode]();
    };

    _opcodes[0xCC] = () { //CALL Z, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_Z) != 0) {
        _machine.contention((_pc + 1) & 0xffff, 1);
        _push((_pc + 2) & 0xffff);
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xCD] = () { //CALL nn
      _memptr = _machine.peek16(_pc);
      _machine.contention((_pc + 1) & 0xffff, 1);
      _push((_pc + 2) & 0xffff);
      _pc = _memptr;
    };

    _opcodes[0xCE] = () { //ADC A, n
      _adcA(_machine.peek8(_pc));
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0xCF] = () { //RST 8
      _machine.contention(_ir, 1);
      _push(_pc);
      _memptr = _pc = 0x0008;
    };

    _opcodes[0xD0] = () { //RET NC
      _machine.contention(_ir, 1);
      if ((_f & _FLAG_C) == 0) {
        _memptr = _pc = _pop();
      }
    };

    _opcodes[0xD1] = () { //POP DE
      _de = _pop();
    };

    _opcodes[0xD2] = () { //JP NC, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_C) == 0) {
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xD3] = () { //OUT (n), A
      var value = _machine.peek8(_pc);
      _memptr = _a << 8;
      _machine.out8(_memptr | value, _a);
      _pc = (_pc + 1) & 0xffff;
      _memptr |= ((value + 1) & 0xff);
    };

    _opcodes[0xD4] = () { //CALL NC, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_C) == 0) {
        _machine.contention((_pc + 1) & 0xffff, 1);
        _push((_pc + 2) & 0xffff);
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xD5] = () { //PUSH DE
      _machine.contention(_ir, 1);
      _push(_de);
    };

    _opcodes[0xD6] = () { //SUB n
      _subA(_machine.peek8(_pc));
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0xD7] = () { //RST 16
      _machine.contention(_ir, 1);
      _push(_pc);
      _memptr = _pc = 0x0010;
    };

    _opcodes[0xD8] = () { //RET C
      _machine.contention(_ir, 1);
      if ((_f & _FLAG_C) != 0) {
        _memptr = _pc = _pop();
      }
    };

    _opcodes[0xD9] = () { //EXX
      var value = _bc;
      _bc = _bcx;
      _bcx = value;

      value = _de;
      _de = _dex;
      _dex = value;

      value = _hl;
      _hl = _hlx;
      _hlx = value;
    };

    _opcodes[0xDA] = () { //JP C, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_C) != 0) {
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xDB] = () { //IN A, (n)
      _memptr = (_a << 8) | _machine.peek8(_pc);
      _a = _machine.in8(_memptr);
      _pc = (_pc + 1) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodes[0xDC] = () { //CALL C, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_C) != 0) {
        _machine.contention((_pc + 1) & 0xffff, 1);
        _push((_pc + 2) & 0xffff);
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xDD] = () { //DD prefix (IX)
      _r = (_r & 0x80) | ((_r + 1) & 0x7f);
      var opcode = _machine.fetchOpcode(_pc);
      _pc = (_pc + 1) & 0xffff;

      if (_opcodesDDFD[opcode] != null) {
        _ix = _opcodesDDFD[opcode](_ix);
      } else {
        _opcodes[opcode]();
      }
    };

    _opcodes[0xDE] = () { //SBC A, n
      _sbcA(_machine.peek8(_pc));
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0xDF] = () { //RST 24
      _machine.contention(_ir, 1);
      _push(_pc);
      _memptr = _pc = 0x0018;
    };

    _opcodes[0xE0] = () { //RET PO
      _machine.contention(_ir, 1);
      if ((_f & _FLAG_P) == 0) {
        _memptr = _pc = _pop();
      }
    };

    _opcodes[0xE1] = () { //POP HL
      _hl = _pop();
    };

    _opcodes[0xE2] = () { //JP PO, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_P) == 0) {
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xE3] = () { //EX (SP), HL
      var value = _hl;
      _memptr = _hl = _machine.peek16(_sp);
      _machine.contention((_sp + 1) & 0xffff, 1);
      _machine.poke8((_sp + 1) & 0xffff, value >> 8);
      _machine.poke8(_sp, value & 0xff);
      _machine.contention(_sp, 2);
    };

    _opcodes[0xE4] = () { //CALL PO, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_P) == 0) {
        _machine.contention((_pc + 1) & 0xffff, 1);
        _push((_pc + 2) & 0xffff);
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xE5] = () { //PUSH HL
      _machine.contention(_ir, 1);
      _push(_hl);
    };

    _opcodes[0xE6] = () { //AND n
      _andA(_machine.peek8(_pc));
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0xE7] = () { //RST 32
      _machine.contention(_ir, 1);
      _push(_pc);
      _memptr = _pc = 0x0020;
    };

    _opcodes[0xE8] = () { //RET PE
      _machine.contention(_ir, 1);
      if ((_f & _FLAG_P) != 0) {
        _memptr = _pc = _pop();
      }
    };

    _opcodes[0xE9] = () { //JP (HL)
      _pc = _hl;
    };

    _opcodes[0xEA] = () { //JP PE, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_P) != 0) {
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xEB] = () { //EX DE, HL
      var value = _de;
      _de = _hl;
      _hl = value;
    };

    _opcodes[0xEC] = () { //CALL PE, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_P) != 0) {
        _machine.contention((_pc + 1) & 0xffff, 1);
        _push((_pc + 2) & 0xffff);
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xED] = () { //ED prefix
      _r = (_r & 0x80) | ((_r + 1) & 0x7f);
      var opcode = _machine.fetchOpcode(_pc);
      _pc = (_pc + 1) & 0xffff;

      if (_opcodesED[opcode] != null) {
        _opcodesED[opcode]();
      }
    };

    _opcodes[0xEE] = () { //XOR n
      _xorA(_machine.peek8(_pc));
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0xEF] = () { //RST 40
      _machine.contention(_ir, 1);
      _push(_pc);
      _memptr = _pc = 0x0028;
    };

    _opcodes[0xF0] = () { //RET P
      _machine.contention(_ir, 1);
      if ((_f & _FLAG_S) == 0) {
        _memptr = _pc = _pop();
      }
    };

    _opcodes[0xF1] = () { //POP AF
      _af = _pop();
    };

    _opcodes[0xF2] = () { //JP P, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_S) == 0) {
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xF3] = () { //DI
      _IFF1 = _IFF2 = false;
    };

    _opcodes[0xF4] = () { //CALL P, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_S) == 0) {
        _machine.contention((_pc + 1) & 0xffff, 1);
        _push((_pc + 2) & 0xffff);
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xF5] = () { //PUSH AF
      _machine.contention(_ir, 1);
      _push(_af);
    };

    _opcodes[0xF6] = () { //OR n
      _orA(_machine.peek8(_pc));
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0xF7] = () { //RST 48
      _machine.contention(_ir, 1);
      _push(_pc);
      _memptr = _pc = 0x0030;
    };

    _opcodes[0xF8] = () { //RET M
      _machine.contention(_ir, 1);
      if ((_f & _FLAG_S) != 0) {
        _memptr = _pc = _pop();
      }
    };

    _opcodes[0xF9] = () { //LD SP, HL
      _machine.contention(_ir, 2);
      _sp = _hl;
    };

    _opcodes[0xFA] = () { //JP M, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_S) != 0) {
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xFB] = () { //EI
      _EI = _IFF1 = _IFF2 = true;
    };

    _opcodes[0xFC] = () { //CALL M, nn
      _memptr = _machine.peek16(_pc);
      if ((_f & _FLAG_S) != 0) {
        _machine.contention((_pc + 1) & 0xffff, 1);
        _push((_pc + 2) & 0xffff);
        _pc = _memptr;
      } else {
        _pc = (_pc + 2) & 0xffff;
      }
    };

    _opcodes[0xFD] = () { //FD prefix (IY)
      _r = (_r & 0x80) | ((_r + 1) & 0x7f);
      var opcode = _machine.fetchOpcode(_pc);
      _pc = (_pc + 1) & 0xffff;

      if (_opcodesDDFD[opcode] != null) {
        _iy = _opcodesDDFD[opcode](_iy);
      } else {
        _opcodes[opcode]();
      }
    };

    _opcodes[0xFE] = () { //CP n
      _cp(_machine.peek8(_pc));
      _pc = (_pc + 1) & 0xffff;
    };

    _opcodes[0xFF] = () { //RST 56
      _machine.contention(_ir, 1);
      _push(_pc);
      _memptr = _pc = 0x0038;
    };
  }

  void _initOpcodesCB() {

    _opcodesCB[0x00] = () { //RLC B
      _b = _rlc8(_b);
    };

    _opcodesCB[0x01] = () { //RLC C
      _c = _rlc8(_c);
    };

    _opcodesCB[0x02] = () { //RLC D
      _d = _rlc8(_d);
    };

    _opcodesCB[0x03] = () { //RLC E
      _e = _rlc8(_e);
    };

    _opcodesCB[0x04] = () { //RLC H
      _h = _rlc8(_h);
    };

    _opcodesCB[0x05] = () { //RLC L
      _l = _rlc8(_l);
    };

    _opcodesCB[0x06] = () { //RLC (HL)
      var value = _rlc8(_machine.peek8(_hl));
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x07] = () { //RLC A
      _a = _rlc8(_a);
    };

    _opcodesCB[0x08] = () { //RRC B
      _b = _rrc8(_b);
    };

    _opcodesCB[0x09] = () { //RRC C
      _c = _rrc8(_c);
    };

    _opcodesCB[0x0A] = () { //RRC D
      _d = _rrc8(_d);
    };

    _opcodesCB[0x0B] = () { //RRC E
      _e = _rrc8(_e);
    };

    _opcodesCB[0x0C] = () { //RRC H
      _h = _rrc8(_h);
    };

    _opcodesCB[0x0D] = () { //RRC L
      _l = _rrc8(_l);
    };

    _opcodesCB[0x0E] = () { //RRC (HL)
      var value = _rrc8(_machine.peek8(_hl));
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x0F] = () { //RRC A
      _a = _rrc8(_a);
    };

    _opcodesCB[0x10] = () { //RL B
      _b = _rl8(_b);
    };

    _opcodesCB[0x11] = () { //RL C
      _c = _rl8(_c);
    };

    _opcodesCB[0x12] = () { //RL D
      _d = _rl8(_d);
    };

    _opcodesCB[0x13] = () { //RL E
      _e = _rl8(_e);
    };

    _opcodesCB[0x14] = () { //RL H
      _h = _rl8(_h);
    };

    _opcodesCB[0x15] = () { //RL L
      _l = _rl8(_l);
    };

    _opcodesCB[0x16] = () { //RL (HL)
      var value = _rl8(_machine.peek8(_hl));
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x17] = () { //RL A
      _a = _rl8(_a);
    };

    _opcodesCB[0x18] = () { //RR B
      _b = _rr8(_b);
    };

    _opcodesCB[0x19] = () { //RR C
      _c = _rr8(_c);
    };

    _opcodesCB[0x1A] = () { //RR D
      _d = _rr8(_d);
    };

    _opcodesCB[0x1B] = () { //RR E
      _e = _rr8(_e);
    };

    _opcodesCB[0x1C] = () { //RR H
      _h = _rr8(_h);
    };

    _opcodesCB[0x1D] = () { //RR L
      _l = _rr8(_l);
    };

    _opcodesCB[0x1E] = () { //RR (HL)
      var value = _rr8(_machine.peek8(_hl));
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x1F] = () { //RR A
      _a = _rr8(_a);
    };

    _opcodesCB[0x20] = () { //SLA B
      _b = _sla8(_b);
    };

    _opcodesCB[0x21] = () { //SLA C
      _c = _sla8(_c);
    };

    _opcodesCB[0x22] = () { //SLA D
      _d = _sla8(_d);
    };

    _opcodesCB[0x23] = () { //SLA E
      _e = _sla8(_e);
    };

    _opcodesCB[0x24] = () { //SLA H
      _h = _sla8(_h);
    };

    _opcodesCB[0x25] = () { //SLA L
      _l = _sla8(_l);
    };

    _opcodesCB[0x26] = () { //SLA (HL)
      var value = _sla8(_machine.peek8(_hl));
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x27] = () { //SLA A
      _a = _sla8(_a);
    };

    _opcodesCB[0x28] = () { //SRA B
      _b = _sra8(_b);
    };

    _opcodesCB[0x29] = () { //SRA C
      _c = _sra8(_c);
    };

    _opcodesCB[0x2A] = () { //SRA D
      _d = _sra8(_d);
    };

    _opcodesCB[0x2B] = () { //SRA E
      _e = _sra8(_e);
    };

    _opcodesCB[0x2C] = () { //SRA H
      _h = _sra8(_h);
    };

    _opcodesCB[0x2D] = () { //SRA L
      _l = _sra8(_l);
    };

    _opcodesCB[0x2E] = () { //SRA (HL)
      var value = _sra8(_machine.peek8(_hl));
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x2F] = () { //SRA A
      _a = _sra8(_a);
    };

    _opcodesCB[0x30] = () { //SLL B
      _b = _sll8(_b);
    };

    _opcodesCB[0x31] = () { //SLL C
      _c = _sll8(_c);
    };

    _opcodesCB[0x32] = () { //SLL D
      _d = _sll8(_d);
    };

    _opcodesCB[0x33] = () { //SLL E
      _e = _sll8(_e);
    };

    _opcodesCB[0x34] = () { //SLL H
      _h = _sll8(_h);
    };

    _opcodesCB[0x35] = () { //SLL L
      _l = _sll8(_l);
    };

    _opcodesCB[0x36] = () { //SLL (HL)
      var value = _sll8(_machine.peek8(_hl));
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x37] = () { //SLL A
      _a = _sll8(_a);
    };

    _opcodesCB[0x38] = () { //SRL B
      _b = _srl8(_b);
    };

    _opcodesCB[0x39] = () { //SRL C
      _c = _srl8(_c);
    };

    _opcodesCB[0x3A] = () { //SRL D
      _d = _srl8(_d);
    };

    _opcodesCB[0x3B] = () { //SRL E
      _e = _srl8(_e);
    };

    _opcodesCB[0x3C] = () { //SRL H
      _h = _srl8(_h);
    };

    _opcodesCB[0x3D] = () { //SRL L
      _l = _srl8(_l);
    };

    _opcodesCB[0x3E] = () { //SRL (HL)
      var value = _srl8(_machine.peek8(_hl));
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x3F] = () { //SRL A
      _a = _srl8(_a);
    };

    _opcodesCB[0x40] = () { //BIT 0, B
      _bit(0x01, _b);
    };

    _opcodesCB[0x41] = () { //BIT 0, C
      _bit(0x01, _c);
    };

    _opcodesCB[0x42] = () { //BIT 0, D
      _bit(0x01, _d);
    };

    _opcodesCB[0x43] = () { //BIT 0, E
      _bit(0x01, _e);
    };

    _opcodesCB[0x44] = () { //BIT 0, H
      _bit(0x01, _h);
    };

    _opcodesCB[0x45] = () { //BIT 0, L
      _bit(0x01, _l);
    };

    _opcodesCB[0x46] = () { //BIT 0, (HL)
      _bit(0x01, _machine.peek8(_hl));
      _f = (_f & _FLAGS_SZHPC) | ((_memptr >> 8) & _FLAGS_53);
      _machine.contention(_hl, 1);
    };

    _opcodesCB[0x47] = () { //BIT 0, A
      _bit(0x01, _a);
    };

    _opcodesCB[0x48] = () { //BIT 1, B
      _bit(0x02, _b);
    };

    _opcodesCB[0x49] = () { //BIT 1, C
      _bit(0x02, _c);
    };

    _opcodesCB[0x4A] = () { //BIT 1, D
      _bit(0x02, _d);
    };

    _opcodesCB[0x4B] = () { //BIT 1, E
      _bit(0x02, _e);
    };

    _opcodesCB[0x4C] = () { //BIT 1, H
      _bit(0x02, _h);
    };

    _opcodesCB[0x4D] = () { //BIT 1, L
      _bit(0x02, _l);
    };

    _opcodesCB[0x4E] = () { //BIT 1, (HL)
      _bit(0x02, _machine.peek8(_hl));
      _f = (_f & _FLAGS_SZHPC) | ((_memptr >> 8) & _FLAGS_53);
      _machine.contention(_hl, 1);
    };

    _opcodesCB[0x4F] = () { //BIT 1, A
      _bit(0x02, _a);
    };

    _opcodesCB[0x50] = () { //BIT 2, B
      _bit(0x04, _b);
    };

    _opcodesCB[0x51] = () { //BIT 2, C
      _bit(0x04, _c);
    };

    _opcodesCB[0x52] = () { //BIT 2, D
      _bit(0x04, _d);
    };

    _opcodesCB[0x53] = () { //BIT 2, E
      _bit(0x04, _e);
    };

    _opcodesCB[0x54] = () { //BIT 2, H
      _bit(0x04, _h);
    };

    _opcodesCB[0x55] = () { //BIT 2, L
      _bit(0x04, _l);
    };

    _opcodesCB[0x56] = () { //BIT 2, (HL)
      _bit(0x04, _machine.peek8(_hl));
      _f = (_f & _FLAGS_SZHPC) | ((_memptr >> 8) & _FLAGS_53);
      _machine.contention(_hl, 1);
    };

    _opcodesCB[0x57] = () { //BIT 2, A
      _bit(0x04, _a);
    };

    _opcodesCB[0x58] = () { //BIT 3, B
      _bit(0x08, _b);
    };

    _opcodesCB[0x59] = () { //BIT 3, C
      _bit(0x08, _c);
    };

    _opcodesCB[0x5A] = () { //BIT 3, D
      _bit(0x08, _d);
    };

    _opcodesCB[0x5B] = () { //BIT 3, E
      _bit(0x08, _e);
    };

    _opcodesCB[0x5C] = () { //BIT 3, H
      _bit(0x08, _h);
    };

    _opcodesCB[0x5D] = () { //BIT 3, L
      _bit(0x08, _l);
    };

    _opcodesCB[0x5E] = () { //BIT 3, (HL)
      _bit(0x08, _machine.peek8(_hl));
      _f = (_f & _FLAGS_SZHPC) | ((_memptr >> 8) & _FLAGS_53);
      _machine.contention(_hl, 1);
    };

    _opcodesCB[0x5F] = () { //BIT 3, A
      _bit(0x08, _a);
    };

    _opcodesCB[0x60] = () { //BIT 4, B
      _bit(0x10, _b);
    };

    _opcodesCB[0x61] = () { //BIT 4, C
      _bit(0x10, _c);
    };

    _opcodesCB[0x62] = () { //BIT 4, D
      _bit(0x10, _d);
    };

    _opcodesCB[0x63] = () { //BIT 4, E
      _bit(0x10, _e);
    };

    _opcodesCB[0x64] = () { //BIT 4, H
      _bit(0x10, _h);
    };

    _opcodesCB[0x65] = () { //BIT 4, L
      _bit(0x10, _l);
    };

    _opcodesCB[0x66] = () { //BIT 4, (HL)
      _bit(0x10, _machine.peek8(_hl));
      _f = (_f & _FLAGS_SZHPC) | ((_memptr >> 8) & _FLAGS_53);
      _machine.contention(_hl, 1);
    };

    _opcodesCB[0x67] = () { //BIT 4, A
      _bit(0x10, _a);
    };

    _opcodesCB[0x68] = () { //BIT 5, B
      _bit(0x20, _b);
    };

    _opcodesCB[0x69] = () { //BIT 5, C
      _bit(0x20, _c);
    };

    _opcodesCB[0x6A] = () { //BIT 5, D
      _bit(0x20, _d);
    };

    _opcodesCB[0x6B] = () { //BIT 5, E
      _bit(0x20, _e);
    };

    _opcodesCB[0x6C] = () { //BIT 5, H
      _bit(0x20, _h);
    };

    _opcodesCB[0x6D] = () { //BIT 5, L
      _bit(0x20, _l);
    };

    _opcodesCB[0x6E] = () { //BIT 5, (HL)
      _bit(0x20, _machine.peek8(_hl));
      _f = (_f & _FLAGS_SZHPC) | ((_memptr >> 8) & _FLAGS_53);
      _machine.contention(_hl, 1);
    };

    _opcodesCB[0x6F] = () { //BIT 5, A
      _bit(0x20, _a);
    };

    _opcodesCB[0x70] = () { //BIT 6, B
      _bit(0x40, _b);
    };

    _opcodesCB[0x71] = () { //BIT 6, C
      _bit(0x40, _c);
    };

    _opcodesCB[0x72] = () { //BIT 6, D
      _bit(0x40, _d);
    };

    _opcodesCB[0x73] = () { //BIT 6, E
      _bit(0x40, _e);
    };

    _opcodesCB[0x74] = () { //BIT 6, H
      _bit(0x40, _h);
    };

    _opcodesCB[0x75] = () { //BIT 6, L
      _bit(0x40, _l);
    };

    _opcodesCB[0x76] = () { //BIT 6, (HL)
      _bit(0x40, _machine.peek8(_hl));
      _f = (_f & _FLAGS_SZHPC) | ((_memptr >> 8) & _FLAGS_53);
      _machine.contention(_hl, 1);
    };

    _opcodesCB[0x77] = () { //BIT 6, A
      _bit(0x40, _a);
    };

    _opcodesCB[0x78] = () { //BIT 7, B
      _bit(0x80, _b);
    };

    _opcodesCB[0x79] = () { //BIT 7, C
      _bit(0x80, _c);
    };

    _opcodesCB[0x7A] = () { //BIT 7, D
      _bit(0x80, _d);
    };

    _opcodesCB[0x7B] = () { //BIT 7, E
      _bit(0x80, _e);
    };

    _opcodesCB[0x7C] = () { //BIT 7, H
      _bit(0x80, _h);
    };

    _opcodesCB[0x7D] = () { //BIT 7, L
      _bit(0x80, _l);
    };

    _opcodesCB[0x7E] = () { //BIT 7, (HL)
      _bit(0x80, _machine.peek8(_hl));
      _f = (_f & _FLAGS_SZHPC) | ((_memptr >> 8) & _FLAGS_53);
      _machine.contention(_hl, 1);
    };

    _opcodesCB[0x7F] = () { //BIT 7, A
      _bit(0x80, _a);
    };

    _opcodesCB[0x80] = () { //RES 0, B
      _b &= 0xfe;
    };

    _opcodesCB[0x81] = () { //RES 0, C
      _c &= 0xfe;
    };

    _opcodesCB[0x82] = () { //RES 0, D
      _d &= 0xfe;
    };

    _opcodesCB[0x83] = () { //RES 0, E
      _e &= 0xfe;
    };

    _opcodesCB[0x84] = () { //RES 0, H
      _h &= 0xfe;
    };

    _opcodesCB[0x85] = () { //RES 0, L
      _l &= 0xfe;
    };

    _opcodesCB[0x86] = () { //RES 0, (HL)
      var value = _machine.peek8(_hl) & 0xfe;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x87] = () { //RES 0, A
      _a &= 0xfe;
    };

    _opcodesCB[0x88] = () { //RES 1, B
      _b &= 0xfd;
    };

    _opcodesCB[0x89] = () { //RES 1, C
      _c &= 0xfd;
    };

    _opcodesCB[0x8A] = () { //RES 1, D
      _d &= 0xfd;
    };

    _opcodesCB[0x8B] = () { //RES 1, E
      _e &= 0xfd;
    };

    _opcodesCB[0x8C] = () { //RES 1, H
      _h &= 0xfd;
    };

    _opcodesCB[0x8D] = () { //RES 1, L
      _l &= 0xfd;
    };

    _opcodesCB[0x8E] = () { //RES 1, (HL)
      var value = _machine.peek8(_hl) & 0xfd;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x8F] = () { //RES 1, A
      _a &= 0xfd;
    };

    _opcodesCB[0x90] = () { //RES 2, B
      _b &= 0xfb;
    };

    _opcodesCB[0x91] = () { //RES 2, C
      _c &= 0xfb;
    };

    _opcodesCB[0x92] = () { //RES 2, D
      _d &= 0xfb;
    };

    _opcodesCB[0x93] = () { //RES 2, E
      _e &= 0xfb;
    };

    _opcodesCB[0x94] = () { //RES 2, H
      _h &= 0xfb;
    };

    _opcodesCB[0x95] = () { //RES 2, L
      _l &= 0xfb;
    };

    _opcodesCB[0x96] = () { //RES 2, (HL)
      var value = _machine.peek8(_hl) & 0xfb;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x97] = () { //RES 2, A
      _a &= 0xfb;
    };

    _opcodesCB[0x98] = () { //RES 3, B
      _b &= 0xf7;
    };

    _opcodesCB[0x99] = () { //RES 3, C
      _c &= 0xf7;
    };

    _opcodesCB[0x9A] = () { //RES 3, D
      _d &= 0xf7;
    };

    _opcodesCB[0x9B] = () { //RES 3, E
      _e &= 0xf7;
    };

    _opcodesCB[0x9C] = () { //RES 3, H
      _h &= 0xf7;
    };

    _opcodesCB[0x9D] = () { //RES 3, L
      _l &= 0xf7;
    };

    _opcodesCB[0x9E] = () { //RES 3, (HL)
      var value = _machine.peek8(_hl) & 0xf7;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0x9F] = () { //RES 3, A
      _a &= 0xf7;
    };

    _opcodesCB[0xA0] = () { //RES 4, B
      _b &= 0xef;
    };

    _opcodesCB[0xA1] = () { //RES 4, C
      _c &= 0xef;
    };

    _opcodesCB[0xA2] = () { //RES 4, D
      _d &= 0xef;
    };

    _opcodesCB[0xA3] = () { //RES 4, E
      _e &= 0xef;
    };

    _opcodesCB[0xA4] = () { //RES 4, H
      _h &= 0xef;
    };

    _opcodesCB[0xA5] = () { //RES 4, L
      _l &= 0xef;
    };

    _opcodesCB[0xA6] = () { //RES 4, (HL)
      var value = _machine.peek8(_hl) & 0xef;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xA7] = () { //RES 4, A
      _a &= 0xef;
    };

    _opcodesCB[0xA8] = () { //RES 5, B
      _b &= 0xdf;
    };

    _opcodesCB[0xA9] = () { //RES 5, C
      _c &= 0xdf;
    };

    _opcodesCB[0xAA] = () { //RES 5, D
      _d &= 0xdf;
    };

    _opcodesCB[0xAB] = () { //RES 5, E
      _e &= 0xdf;
    };

    _opcodesCB[0xAC] = () { //RES 5, H
      _h &= 0xdf;
    };

    _opcodesCB[0xAD] = () { //RES 5, L
      _l &= 0xdf;
    };

    _opcodesCB[0xAE] = () { //RES 5, (HL)
      var value = _machine.peek8(_hl) & 0xdf;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xAF] = () { //RES 5, A
      _a &= 0xdf;
    };

    _opcodesCB[0xB0] = () { //RES 6, B
      _b &= 0xbf;
    };

    _opcodesCB[0xB1] = () { //RES 6, C
      _c &= 0xbf;
    };

    _opcodesCB[0xB2] = () { //RES 6, D
      _d &= 0xbf;
    };

    _opcodesCB[0xB3] = () { //RES 6, E
      _e &= 0xbf;
    };

    _opcodesCB[0xB4] = () { //RES 6, H
      _h &= 0xbf;
    };

    _opcodesCB[0xB5] = () { //RES 6, L
      _l &= 0xbf;
    };

    _opcodesCB[0xB6] = () { //RES 6, (HL)
      var value = _machine.peek8(_hl) & 0xbf;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xB7] = () { //RES 6, A
      _a &= 0xbf;
    };

    _opcodesCB[0xB8] = () { //RES 7, B
      _b &= 0x7f;
    };

    _opcodesCB[0xB9] = () { //RES 7, C
      _c &= 0x7f;
    };

    _opcodesCB[0xBA] = () { //RES 7, D
      _d &= 0x7f;
    };

    _opcodesCB[0xBB] = () { //RES 7, E
      _e &= 0x7f;
    };

    _opcodesCB[0xBC] = () { //RES 7, H
      _h &= 0x7f;
    };

    _opcodesCB[0xBD] = () { //RES 7, L
      _l &= 0x7f;
    };

    _opcodesCB[0xBE] = () { //RES 7, (HL)
      var value = _machine.peek8(_hl) & 0x7f;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xBF] = () { //RES 7, A
      _a &= 0x7f;
    };

    _opcodesCB[0xC0] = () { //SET 0, B
      _b |= 0x01;
    };

    _opcodesCB[0xC1] = () { //SET 0, C
      _c |= 0x01;
    };

    _opcodesCB[0xC2] = () { //SET 0, D
      _d |= 0x01;
    };

    _opcodesCB[0xC3] = () { //SET 0, E
      _e |= 0x01;
    };

    _opcodesCB[0xC4] = () { //SET 0, H
      _h |= 0x01;
    };

    _opcodesCB[0xC5] = () { //SET 0, L
      _l |= 0x01;
    };

    _opcodesCB[0xC6] = () { //SET 0, (HL)
      var value = _machine.peek8(_hl) | 0x01;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xC7] = () { //SET 0, A
      _a |= 0x01;
    };

    _opcodesCB[0xC8] = () { //SET 1, B
      _b |= 0x02;
    };

    _opcodesCB[0xC9] = () { //SET 1, C
      _c |= 0x02;
    };

    _opcodesCB[0xCA] = () { //SET 1, D
      _d |= 0x02;
    };

    _opcodesCB[0xCB] = () { //SET 1, E
      _e |= 0x02;
    };

    _opcodesCB[0xCC] = () { //SET 1, H
      _h |= 0x02;
    };

    _opcodesCB[0xCD] = () { //SET 1, L
      _l |= 0x02;
    };

    _opcodesCB[0xCE] = () { //SET 1, (HL)
      var value = _machine.peek8(_hl) | 0x02;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xCF] = () { //SET 1, A
      _a |= 0x02;
    };

    _opcodesCB[0xD0] = () { //SET 2, B
      _b |= 0x04;
    };

    _opcodesCB[0xD1] = () { //SET 2, C
      _c |= 0x04;
    };

    _opcodesCB[0xD2] = () { //SET 2, D
      _d |= 0x04;
    };

    _opcodesCB[0xD3] = () { //SET 2, E
      _e |= 0x04;
    };

    _opcodesCB[0xD4] = () { //SET 2, H
      _h |= 0x04;
    };

    _opcodesCB[0xD5] = () { //SET 2, L
      _l |= 0x04;
    };

    _opcodesCB[0xD6] = () { //SET 2, (HL)
      var value = _machine.peek8(_hl) | 0x04;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xD7] = () { //SET 2, A
      _a |= 0x04;
    };

    _opcodesCB[0xD8] = () { //SET 3, B
      _b |= 0x08;
    };

    _opcodesCB[0xD9] = () { //SET 3, C
      _c |= 0x08;
    };

    _opcodesCB[0xDA] = () { //SET 3, D
      _d |= 0x08;
    };

    _opcodesCB[0xDB] = () { //SET 3, E
      _e |= 0x08;
    };

    _opcodesCB[0xDC] = () { //SET 3, H
      _h |= 0x08;
    };

    _opcodesCB[0xDD] = () { //SET 3, L
      _l |= 0x08;
    };

    _opcodesCB[0xDE] = () { //SET 3, (HL)
      var value = _machine.peek8(_hl) | 0x08;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xDF] = () { //SET 3, A
      _a |= 0x08;
    };

    _opcodesCB[0xE0] = () { //SET 4, B
      _b |= 0x10;
    };

    _opcodesCB[0xE1] = () { //SET 4, C
      _c |= 0x10;
    };

    _opcodesCB[0xE2] = () { //SET 4, D
      _d |= 0x10;
    };

    _opcodesCB[0xE3] = () { //SET 4, E
      _e |= 0x10;
    };

    _opcodesCB[0xE4] = () { //SET 4, H
      _h |= 0x10;
    };

    _opcodesCB[0xE5] = () { //SET 4, L
      _l |= 0x10;
    };

    _opcodesCB[0xE6] = () { //SET 4, (HL)
      var value = _machine.peek8(_hl) | 0x10;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xE7] = () { //SET 4, A
      _a |= 0x10;
    };

    _opcodesCB[0xE8] = () { //SET 5, B
      _b |= 0x20;
    };

    _opcodesCB[0xE9] = () { //SET 5, C
      _c |= 0x20;
    };

    _opcodesCB[0xEA] = () { //SET 5, D
      _d |= 0x20;
    };

    _opcodesCB[0xEB] = () { //SET 5, E
      _e |= 0x20;
    };

    _opcodesCB[0xEC] = () { //SET 5, H
      _h |= 0x20;
    };

    _opcodesCB[0xED] = () { //SET 5, L
      _l |= 0x20;
    };

    _opcodesCB[0xEE] = () { //SET 5, (HL)
      var value = _machine.peek8(_hl) | 0x20;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xEF] = () { //SET 5, A
      _a |= 0x20;
    };

    _opcodesCB[0xF0] = () { //SET 6, B
      _b |= 0x40;
    };

    _opcodesCB[0xF1] = () { //SET 6, C
      _c |= 0x40;
    };

    _opcodesCB[0xF2] = () { //SET 6, D
      _d |= 0x40;
    };

    _opcodesCB[0xF3] = () { //SET 6, E
      _e |= 0x40;
    };

    _opcodesCB[0xF4] = () { //SET 6, H
      _h |= 0x40;
    };

    _opcodesCB[0xF5] = () { //SET 6, L
      _l |= 0x40;
    };

    _opcodesCB[0xF6] = () { //SET 6, (HL)
      var value = _machine.peek8(_hl) | 0x40;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xF7] = () { //SET 6, A
      _a |= 0x40;
    };

    _opcodesCB[0xF8] = () { //SET 7, B
      _b |= 0x80;
    };

    _opcodesCB[0xF9] = () { //SET 7, C
      _c |= 0x80;
    };

    _opcodesCB[0xFA] = () { //SET 7, D
      _d |= 0x80;
    };

    _opcodesCB[0xFB] = () { //SET 7, E
      _e |= 0x80;
    };

    _opcodesCB[0xFC] = () { //SET 7, H
      _h |= 0x80;
    };

    _opcodesCB[0xFD] = () { //SET 7, L
      _l |= 0x80;
    };

    _opcodesCB[0xFE] = () { //SET 7, (HL)
      var value = _machine.peek8(_hl) | 0x80;
      _machine.contention(_hl, 1);
      _machine.poke8(_hl, value);
    };

    _opcodesCB[0xFF] = () { //SET 7, A
      _a |= 0x80;
    };
  }

  void _initOpcodesED() {

    _opcodesED[0x40] = () { //IN B, (C)
      _b = _machine.in8(_bc);
      _f = _sz53pn_add[_b] | (_f & _FLAG_C);
    };

    _opcodesED[0x41] = () { //OUT (C), B
      _machine.out8(_bc, _b);
    };

    _opcodesED[0x42] = () { //SBC HL, BC
      _machine.contention(_ir, 7);
      _sbcHL(_bc);
    };

    _opcodesED[0x43] = () { //LD (nn), BC
      _memptr = _machine.peek16(_pc);
      _machine.poke16(_memptr, _bc);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodesED[0x44] = //NEG
    _opcodesED[0x4C] = _opcodesED[0x54] = _opcodesED[0x5C] = _opcodesED[0x64] = _opcodesED[0x6C] = _opcodesED[0x74] = _opcodesED[0x7C] = () {
      var value = _a;
      _a = 0;
      _subA(value);
    };

    _opcodesED[0x45] = //RETN
    _opcodesED[0x4D] = //RETI
    _opcodesED[0x55] = _opcodesED[0x5D] = _opcodesED[0x65] = _opcodesED[0x6D] = _opcodesED[0x75] = _opcodesED[0x7D] = () {
      _IFF1 = _IFF2;
      _memptr = _pc = _pop();
    };

    _opcodesED[0x46] = //IM 0
    _opcodesED[0x4E] = _opcodesED[0x66] = _opcodesED[0x6E] = () {
      _im = 0;
    };

    _opcodesED[0x47] = () { //LD I, A
      _machine.contention(_ir, 1);
      _i = _a;
    };

    _opcodesED[0x48] = () { //IN C, (C)
      _c = _machine.in8(_bc);
      _f = _sz53pn_add[_c] | (_f & _FLAG_C);
    };

    _opcodesED[0x49] = () { //OUT (C), C
      _machine.out8(_bc, _c);
    };

    _opcodesED[0x4A] = () { //ADC HL, BC
      _machine.contention(_ir, 7);
      _adcHL(_bc);
    };

    _opcodesED[0x4B] = () { //LD BC, (nn)
      _memptr = _machine.peek16(_pc);
      _bc = _machine.peek16(_memptr);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodesED[0x4F] = () { //LD R, A
      _machine.contention(_ir, 1);
      _r = _a;
    };

    _opcodesED[0x50] = () { //IN D, (C)
      _d = _machine.in8(_bc);
      _f = _sz53pn_add[_d] | (_f & _FLAG_C);
    };

    _opcodesED[0x51] = () { //OUT (C), D
      _machine.out8(_bc, _d);
    };

    _opcodesED[0x52] = () { //SBC HL, DE
      _machine.contention(_ir, 7);
      _sbcHL(_de);
    };

    _opcodesED[0x53] = () { //LD (nn), DE
      _memptr = _machine.peek16(_pc);
      _machine.poke16(_memptr, _de);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodesED[0x56] = //IM 1
    _opcodesED[0x76] = () {
      _im = 1;
    };

    _opcodesED[0x57] = () { //LD A, I
      _machine.contention(_ir, 1);
      _a = _i;
      _f = _sz53n_add[_a] | (_f & _FLAG_C);
      if (_IFF2) {
        _f |= _FLAG_P;
      }
    };

    _opcodesED[0x58] = () { //IN E, (C)
      _e = _machine.in8(_bc);
      _f = _sz53pn_add[_e] | (_f & _FLAG_C);
    };

    _opcodesED[0x59] = () { //OUT (C), E
      _machine.out8(_bc, _e);
    };

    _opcodesED[0x5A] = () { //ADC HL, DE
      _machine.contention(_ir, 7);
      _adcHL(_de);
    };

    _opcodesED[0x5B] = () { //LD DE, (nn)
      _memptr = _machine.peek16(_pc);
      _de = _machine.peek16(_memptr);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodesED[0x5E] = //IM 2
    _opcodesED[0x7E] = () {
      _im = 2;
    };

    _opcodesED[0x5F] = () { //LD A, R
      _machine.contention(_ir, 1);
      _a = _r;
      _f = _sz53n_add[_a] | (_f & _FLAG_C);
      if (_IFF2) {
        _f |= _FLAG_P;
      }
    };

    _opcodesED[0x60] = () { //IN H, (C)
      _h = _machine.in8(_bc);
      _f = _sz53pn_add[_h] | (_f & _FLAG_C);
    };

    _opcodesED[0x61] = () { //OUT (C), H
      _machine.out8(_bc, _h);
    };

    _opcodesED[0x62] = () { //SBC HL,HL
      _machine.contention(_ir, 7);
      _sbcHL(_hl);
    };

    _opcodesED[0x63] = () { //LD (nn), HL
      _memptr = _machine.peek16(_pc);
      _machine.poke16(_memptr, _hl);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodesED[0x67] = () { //RRD
      _rrd();
    };

    _opcodesED[0x68] = () { //IN L, (C)
      _l = _machine.in8(_bc);
      _f = _sz53pn_add[_l] | (_f & _FLAG_C);
    };

    _opcodesED[0x69] = () { //OUT (C), L
      _machine.out8(_bc, _l);
    };

    _opcodesED[0x6A] = () { //ADC HL,HL
      _machine.contention(_ir, 7);
      _adcHL(_hl);
    };

    _opcodesED[0x6B] = () { //LD HL, (nn)
      _memptr = _machine.peek16(_pc);
      _hl = _machine.peek16(_memptr);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodesED[0x6F] = () { //RLD
      _rld();
    };

    _opcodesED[0x70] = () { //IN (C)
      _f = _sz53pn_add[_machine.in8(_bc)] | (_f & _FLAG_C);
    };

    _opcodesED[0x71] = () { //OUT (C), 0
      _machine.out8(_bc, 0);
    };

    _opcodesED[0x72] = () { //SBC HL,SP
      _machine.contention(_ir, 7);
      _sbcHL(_sp);
    };

    _opcodesED[0x73] = () { //LD (nn), SP
      _memptr = _machine.peek16(_pc);
      _machine.poke16(_memptr, _sp);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodesED[0x78] = () { //IN A, (C)
      _a = _machine.in8(_bc);
      _f = _sz53pn_add[_a] | (_f & _FLAG_C);
      _memptr = (_bc + 1) & 0xffff;
    };

    _opcodesED[0x79] = () { //OUT (C), A
      _machine.out8(_bc, _a);
      _memptr = (_bc + 1) & 0xffff;
    };

    _opcodesED[0x7A] = () { //ADC HL, SP
      _machine.contention(_ir, 7);
      _adcHL(_sp);
    };

    _opcodesED[0x7B] = () { //LD SP, (nn)
      _memptr = _machine.peek16(_pc);
      _sp = _machine.peek16(_memptr);
      _pc = (_pc + 2) & 0xffff;
      _memptr = (_memptr + 1) & 0xffff;
    };

    _opcodesED[0xA0] = () { //LDI
      _ldi();
    };

    _opcodesED[0xA1] = () { //CPI
      _cpi();
    };

    _opcodesED[0xA2] = () { //INI
      _ini();
    };

    _opcodesED[0xA3] = () { //OUTI
      _outi();
    };

    _opcodesED[0xA8] = () { //LDD
      _ldd();
    };

    _opcodesED[0xA9] = () { //CPD
      _cpd();
    };

    _opcodesED[0xAA] = () { //IND
      _ind();
    };

    _opcodesED[0xAB] = () { //OUTD
      _outd();
    };

    _opcodesED[0xB0] = () { //LDIR
      _ldi();
      if ((_f & _FLAG_P) != 0) {
        _pc = (_pc - 2) & 0xffff;
        _machine.contention((_de - 1) & 0xffff, 5);
        _memptr = (_pc + 1) & 0xffff;
      }
    };

    _opcodesED[0xB1] = () { //CPIR
      _cpi();
      if (((_f & _FLAG_P) != 0) && (_f & _FLAG_Z) == 0) {
        _pc = (_pc - 2) & 0xffff;
        _machine.contention((_hl - 1) & 0xffff, 5);
        _memptr = (_pc + 1) & 0xffff;
      }
    };

    _opcodesED[0xB2] = () { //INIR
      _ini();
      if (_b != 0) {
        _pc = (_pc - 2) & 0xffff;
        _machine.contention((_hl - 1) & 0xffff, 5);
      }
    };

    _opcodesED[0xB3] = () { //OTIR
      _outi();
      if (_b != 0) {
        _pc = (_pc - 2) & 0xffff;
        _machine.contention(_bc, 5);
      }
    };

    _opcodesED[0xB8] = () { //LDDR
      _ldd();
      if ((_f & _FLAG_P) != 0) {
        _pc = (_pc - 2) & 0xffff;
        _machine.contention((_de + 1) & 0xffff, 5);
        _memptr = (_pc + 1) & 0xffff;
      }
    };

    _opcodesED[0xB9] = () { //CPDR
      _cpd();
      if (((_f & _FLAG_P) != 0) && (_f & _FLAG_Z) == 0) {
        _pc = (_pc - 2) & 0xffff;
        _machine.contention((_hl + 1) & 0xffff, 5);
        _memptr = (_pc + 1) & 0xffff;
      }
    };

    _opcodesED[0xBA] = () { //INDR
      _ind();
      if (_b != 0) {
        _pc = (_pc - 2) & 0xffff;
        _machine.contention((_hl + 1) & 0xffff, 5);
      }
    };

    _opcodesED[0xBB] = () { //OTDR
      _outd();
      if (_b != 0) {
        _pc = (_pc - 2) & 0xffff;
        _machine.contention(_bc, 5);
      }
    };
  }

  void _initOpcodesDDFD() {

    _opcodesDDFD[0x09] = (int ixy) { //ADD IX/IY, BC
      _machine.contention(_ir, 7);
      return _add16(ixy, _bc);
    };

    _opcodesDDFD[0x19] = (int ixy) { //ADD IX/IY,DE
      _machine.contention(_ir, 7);
      return _add16(ixy, _de);
    };

    _opcodesDDFD[0x21] = (int ixy) { //LD IX/IY, nn
      ixy = _machine.peek16(_pc);
      _pc = (_pc + 2) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x22] = (int ixy) { //LD (nn), IX/IY
      _memptr = _machine.peek16(_pc);
      _machine.poke16(_memptr, ixy);
      _memptr = (_memptr + 1) & 0xffff;
      _pc = (_pc + 2) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x23] = (int ixy) { //INC IX/IY
      _machine.contention(_ir, 2);
      return (ixy + 1) & 0xffff;
    };

    _opcodesDDFD[0x24] = (int ixy) { //INC IX/IYH
      return (_inc8(ixy >> 8) << 8) | (ixy & 0xff);
    };

    _opcodesDDFD[0x25] = (int ixy) { //DEC IX/IYH
      return (_dec8(ixy >> 8) << 8) | (ixy & 0xff);
    };

    _opcodesDDFD[0x26] = (int ixy) { //LD IX/IYH, n
      ixy = (_machine.peek8(_pc) << 8) | (ixy & 0xff);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x29] = (int ixy) { //ADD IX/IY, IX/IY
      _machine.contention(_ir, 7);
      return _add16(ixy, ixy);
    };

    _opcodesDDFD[0x2A] = (int ixy) { //LD IX/IY, (nn)
      _memptr = _machine.peek16(_pc);
      ixy = _machine.peek16(_memptr);
      _memptr = (_memptr + 1) & 0xffff;
      _pc = (_pc + 2) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x2B] = (int ixy) { //DEC IX/IY
      _machine.contention(_ir, 2);
      return (ixy - 1) & 0xffff;
    };

    _opcodesDDFD[0x2C] = (int ixy) { //INC IX/IYL
      return (ixy & 0xff00) | _inc8(ixy & 0xff);
    };

    _opcodesDDFD[0x2D] = (int ixy) { //DEC IX/IYL
      return (ixy & 0xff00) | _dec8(ixy & 0xff);
    };

    _opcodesDDFD[0x2E] = (int ixy) { //LD IX/IYL, n
      ixy = (ixy & 0xff00) | _machine.peek8(_pc);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x34] = (int ixy) { //INC (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      value = _machine.peek8(_memptr);
      _machine.contention(_memptr, 1);
      _machine.poke8(_memptr, _inc8(value));
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x35] = (int ixy) { //DEC (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      value = _machine.peek8(_memptr);
      _machine.contention(_memptr, 1);
      _machine.poke8(_memptr, _dec8(value));
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x36] = (int ixy) { //LD (IX/IY + offset),n
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _pc = (_pc + 1) & 0xffff;
      value = _machine.peek8(_pc);
      _machine.contention(_pc, 2);
      _machine.poke8(_memptr, value);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x39] = (int ixy) { //ADD IX/IY, SP
      _machine.contention(_ir, 7);
      return _add16(ixy, _sp);
    };

    _opcodesDDFD[0x44] = (int ixy) { //LD B, IX/IYH
      _b = ixy >> 8;
      return ixy;
    };

    _opcodesDDFD[0x45] = (int ixy) { //LD B, IX/IYL
      _b = ixy & 0xff;
      return ixy;
    };

    _opcodesDDFD[0x46] = (int ixy) { //LD B, (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _b = _machine.peek8(_memptr);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x4C] = (int ixy) { //LD C, IX/IYH
      _c = ixy >> 8;
      return ixy;
    };

    _opcodesDDFD[0x4D] = (int ixy) { //LD C, IX/IYL
      _c = ixy & 0xff;
      return ixy;
    };

    _opcodesDDFD[0x4E] = (int ixy) { //LD C, (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _c = _machine.peek8(_memptr);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x54] = (int ixy) { //LD D, IX/IYH
      _d = ixy >> 8;
      return ixy;
    };

    _opcodesDDFD[0x55] = (int ixy) { //LD D, IX/IYL
      _d = ixy & 0xff;
      return ixy;
    };

    _opcodesDDFD[0x56] = (int ixy) { //LD D, (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _d = _machine.peek8(_memptr);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x5C] = (int ixy) { //LD E, IX/IYH
      _e = ixy >> 8;
      return ixy;
    };

    _opcodesDDFD[0x5D] = (int ixy) { //LD E, IX/IYL
      _e = ixy & 0xff;
      return ixy;
    };

    _opcodesDDFD[0x5E] = (int ixy) { //LD E, (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _e = _machine.peek8(_memptr);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x60] = (int ixy) { //LD IX/IYH, B
      return (ixy & 0xff) | (_b << 8);
    };

    _opcodesDDFD[0x61] = (int ixy) { //LD IX/IYH, C
      return (ixy & 0xff) | (_c << 8);
    };

    _opcodesDDFD[0x62] = (int ixy) { //LD IX/IYH, D
      return (ixy & 0xff) | (_d << 8);
    };

    _opcodesDDFD[0x63] = (int ixy) { //LD IX/IYh,E
      return (ixy & 0xff) | (_e << 8);
    };

    _opcodesDDFD[0x64] = (int ixy) { //LD IX/IYH, IX/IYH
      return ixy;
    };

    _opcodesDDFD[0x65] = (int ixy) { //LD IX/IYH, IX/IYL
      return (ixy & 0xff) | ((ixy & 0xff) << 8);
    };

    _opcodesDDFD[0x66] = (int ixy) { //LD H, (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _h = _machine.peek8(_memptr);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x67] = (int ixy) { //LD IX/IYH, A
      return (ixy & 0xff) | (_a << 8);
    };

    _opcodesDDFD[0x68] = (int ixy) { //LD IX/IYL, B
      return (ixy & 0xff00) | _b;
    };

    _opcodesDDFD[0x69] = (int ixy) { //LD IX/IYL,C
      return (ixy & 0xff00) | _c;
    };

    _opcodesDDFD[0x6A] = (int ixy) { //LD IX/IYL, D
      return (ixy & 0xff00) | _d;
    };

    _opcodesDDFD[0x6B] = (int ixy) { //LD IX/IYL, E
      return (ixy & 0xff00) | _e;
    };

    _opcodesDDFD[0x6C] = (int ixy) { //LD IX/IYL, IX/IYH
      return (ixy & 0xff00) | (ixy >> 8);
    };

    _opcodesDDFD[0x6D] = (int ixy) { //LD IX/IYL, IX/IYL
      return ixy;
    };

    _opcodesDDFD[0x6E] = (int ixy) { //LD L, (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _l = _machine.peek8(_memptr);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x6F] = (int ixy) { //LD IX/IYL, A
      return (ixy & 0xff00) | _a;
    };

    _opcodesDDFD[0x70] = (int ixy) { //LD (IX/IY + offset), B
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _machine.poke8(_memptr, _b);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x71] = (int ixy) { //LD (IX/IY + offset), C
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _machine.poke8(_memptr, _c);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x72] = (int ixy) { //LD (IX/IY + offset), D
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _machine.poke8(_memptr, _d);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x73] = (int ixy) { //LD (IX/IY + offset), E
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _machine.poke8(_memptr, _e);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x74] = (int ixy) { //LD (IX/IY + offset), H
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _machine.poke8(_memptr, _h);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x75] = (int ixy) { //LD (IX/IY + offset), L
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _machine.poke8(_memptr, _l);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x77] = (int ixy) { //LD (IX/IY + offset), A
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _machine.poke8(_memptr, _a);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x7C] = (int ixy) { //LD A, IX/IYH
      _a = ixy >> 8;
      return ixy;
    };

    _opcodesDDFD[0x7D] = (int ixy) { //LD A, IX/IYL
      _a = ixy & 0xff;
      return ixy;
    };

    _opcodesDDFD[0x7E] = (int ixy) { //LD A, (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _a = _machine.peek8(_memptr);
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x84] = (int ixy) { //ADD A, IX/IYH
      _addA(ixy >> 8);
      return ixy;
    };

    _opcodesDDFD[0x85] = (int ixy) { //ADD A, IX/IYL
      _addA(ixy & 0xff);
      return ixy;
    };

    _opcodesDDFD[0x86] = (int ixy) { //ADD A, (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _addA(_machine.peek8(_memptr));
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x8C] = (int ixy) { //ADC A, IX/IYH
      _adcA(ixy >> 8);
      return ixy;
    };

    _opcodesDDFD[0x8D] = (int ixy) { //ADC A, IX/IYL
      _adcA(ixy & 0xff);
      return ixy;
    };

    _opcodesDDFD[0x8E] = (int ixy) { //ADC A, (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _adcA(_machine.peek8(_memptr));
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x94] = (int ixy) { //SUB IX/IYH
      _subA(ixy >> 8);
      return ixy;
    };

    _opcodesDDFD[0x95] = (int ixy) { //SUB IX/IYL
      _subA(ixy & 0xff);
      return ixy;
    };

    _opcodesDDFD[0x96] = (int ixy) { //SUB (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _subA(_machine.peek8(_memptr));
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0x9C] = (int ixy) { //SBC A, IX/IYH
      _sbcA(ixy >> 8);
      return ixy;
    };

    _opcodesDDFD[0x9D] = (int ixy) { //SBC A, IX/IYL
      _sbcA(ixy & 0xff);
      return ixy;
    };

    _opcodesDDFD[0x9E] = (int ixy) { //SBC A, (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _sbcA(_machine.peek8(_memptr));
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0xA4] = (int ixy) { //AND IX/IYH
      _andA(ixy >> 8);
      return ixy;
    };

    _opcodesDDFD[0xA5] = (int ixy) { //AND IX/IYL
      _andA(ixy & 0xff);
      return ixy;
    };

    _opcodesDDFD[0xA6] = (int ixy) { //AND (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _andA(_machine.peek8(_memptr));
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0xAC] = (int ixy) { //XOR IX/IYH
      _xorA(ixy >> 8);
      return ixy;
    };

    _opcodesDDFD[0xAD] = (int ixy) { //XOR IX/IYL
      _xorA(ixy & 0xff);
      return ixy;
    };

    _opcodesDDFD[0xAE] = (int ixy) { //XOR (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _xorA(_machine.peek8(_memptr));
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0xB4] = (int ixy) { //OR IX/IYH
      _orA(ixy >> 8);
      return ixy;
    };

    _opcodesDDFD[0xB5] = (int ixy) { //OR IX/IYL
      _orA(ixy & 0xff);
      return ixy;
    };

    _opcodesDDFD[0xB6] = (int ixy) { //OR (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _orA(_machine.peek8(_memptr));
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0xBC] = (int ixy) { //CP IX/IYH
      _cp(ixy >> 8);
      return ixy;
    };

    _opcodesDDFD[0xBD] = (int ixy) { //CP IX/IYL
      _cp(ixy & 0xff);
      return ixy;
    };

    _opcodesDDFD[0xBE] = (int ixy) { //CP (IX/IY + offset)
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _machine.contention(_pc, 5);
      _cp(_machine.peek8(_memptr));
      _pc = (_pc + 1) & 0xffff;
      return ixy;
    };

    _opcodesDDFD[0xCB] = (int ixy) { //CB prefix
      int value = ((_machine.peek8(_pc) + 128) & 0xff) - 128;
      _memptr = (ixy + value) & 0xffff;
      _pc = (_pc + 1) & 0xffff;
      value = _machine.peek8(_pc);
      _machine.contention(_pc, 2);
      _pc = (_pc + 1) & 0xffff;

      _opcodesDDFDCB[value](_memptr);

      return ixy;
    };

    _opcodesDDFD[0xE1] = (int ixy) { //POP IX/IY
      return _pop();
    };

    _opcodesDDFD[0xE3] = (int ixy) { //EX (SP), IX/IY
      var value = ixy;
      _memptr = ixy = _machine.peek16(_sp);
      _machine.contention((_sp + 1) & 0xffff, 1);
      _machine.poke8((_sp + 1) & 0xffff, value >> 8);
      _machine.poke8(_sp, value & 0xff);
      _machine.contention(_sp, 2);
      return ixy;
    };

    _opcodesDDFD[0xE5] = (int ixy) { //PUSH IX/IY
      _machine.contention(_ir, 1);
      _push(ixy);
      return ixy;
    };

    _opcodesDDFD[0xE9] = (int ixy) { //JP (IX/IY)
      _pc = ixy;
      return ixy;
    };

    _opcodesDDFD[0xF9] = (int ixy) { //LD SP, IX/IY
      _machine.contention(_ir, 2);
      _sp = ixy;
      return ixy;
    };
  }

  void _initOpcodesDDFDCB() {

    _opcodesDDFDCB[0x00] = (int address) { //RLC (IX/IY + offset), B
      _b = _rlc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x01] = (int address) { //RLC (IX/IY + offset), C
      _c = _rlc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x02] = (int address) { //RLC (IX/IY + offset), D
      _d = _rlc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x03] = (int address) { //RLC (IX/IY + offset), E
      _e = _rlc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x04] = (int address) { //RLC (IX/IY + offset), H
      _h = _rlc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x05] = (int address) { //RLC (IX/IY + offset), L
      _l = _rlc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x06] = (int address) { //RLC (IX/IY + offset)
      var value = _rlc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x07] = (int address) { //RLC (IX/IY + offset), A
      _a = _rlc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0x08] = (int address) { //RRC (IX/IY + offset), B
      _b = _rrc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x09] = (int address) { //RRC (IX/IY + offset), C
      _c = _rrc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x0A] = (int address) { //RRC (IX/IY + offset), D
      _d = _rrc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x0B] = (int address) { //RRC (IX/IY + offset), E
      _e = _rrc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x0C] = (int address) { //RRC (IX/IY + offset), H
      _h = _rrc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x0D] = (int address) { //RRC (IX/IY + offset), L
      _l = _rrc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x0E] = (int address) { //RRC (IX/IY + offset)
      var value = _rrc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x0F] = (int address) { //RRC (IX/IY + offset), A
      _a = _rrc8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0x10] = (int address) { //RL (IX/IY + offset), B
      _b = _rl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x11] = (int address) { //RL (IX/IY + offset), C
      _c = _rl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x12] = (int address) { //RL (IX/IY + offset), D
      _d = _rl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x13] = (int address) { //RL (IX/IY + offset), E
      _e = _rl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x14] = (int address) { //RL (IX/IY + offset), H
      _h = _rl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x15] = (int address) { //RL (IX/IY + offset), L
      _l = _rl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x16] = (int address) { //RL (IX/IY + offset)
      var value = _rl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x17] = (int address) { //RL (IX/IY + offset), A
      _a = _rl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0x18] = (int address) { //RR (IX/IY + offset), B
      _b = _rr8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x19] = (int address) { //RR (IX/IY + offset), C
      _c = _rr8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x1A] = (int address) { //RR (IX/IY + offset), D
      _d = _rr8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x1B] = (int address) { //RR (IX/IY + offset), E
      _e = _rr8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x1C] = (int address) { //RR (IX/IY + offset), H
      _h = _rr8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x1D] = (int address) { //RR (IX/IY + offset), L
      _l = _rr8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x1E] = (int address) { //RR (IX/IY + offset)
      var value = _rr8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x1F] = (int address) { //RR (IX/IY + offset), A
      _a = _rr8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0x20] = (int address) { //SLA (IX/IY + offset), B
      _b = _sla8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x21] = (int address) { //SLA (IX/IY + offset), C
      _c = _sla8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x22] = (int address) { //SLA (IX/IY + offset), D
      _d = _sla8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x23] = (int address) { //SLA (IX/IY + offset), E
      _e = _sla8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x24] = (int address) { //SLA (IX/IY + offset), H
      _h = _sla8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x25] = (int address) { //SLA (IX/IY + offset), L
      _l = _sla8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x26] = (int address) { //SLA (IX/IY + offset)
      var value = _sla8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x27] = (int address) { //SLA (IX/IY + offset), A
      _a = _sla8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0x28] = (int address) { //SRA (IX/IY + offset), B
      _b = _sra8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x29] = (int address) { //SRA (IX/IY + offset), C
      _c = _sra8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x2A] = (int address) { //SRA (IX/IY + offset), D
      _d = _sra8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x2B] = (int address) { //SRA (IX/IY + offset), E
      _e = _sra8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x2C] = (int address) { //SRA (IX/IY + offset), H
      _h = _sra8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x2D] = (int address) { //SRA (IX/IY + offset), L
      _l = _sra8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x2E] = (int address) { //SRA (IX/IY + offset)
      var value = _sra8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x2F] = (int address) { //SRA (IX/IY + offset), A
      _a = _sra8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0x30] = (int address) { //SLL (IX/IY + offset), B
      _b = _sll8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x31] = (int address) { //SLL (IX/IY + offset), C
      _c = _sll8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x32] = (int address) { //SLL (IX/IY + offset), D
      _d = _sll8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x33] = (int address) { //SLL (IX/IY + offset), E
      _e = _sll8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x34] = (int address) { //SLL (IX/IY + offset), H
      _h = _sll8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x35] = (int address) { //SLL (IX/IY + offset), L
      _l = _sll8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x36] = (int address) { //SLL (IX/IY + offset)
      var value = _sll8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x37] = (int address) { //SLL (IX/IY + offset), A
      _a = _sll8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0x38] = (int address) { //SRL (IX/IY + offset), B
      _b = _srl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x39] = (int address) { //SRL (IX/IY + offset), C
      _c = _srl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x3A] = (int address) { //SRL (IX/IY + offset), D
      _d = _srl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x3B] = (int address) { //SRL (IX/IY + offset), E
      _e = _srl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x3C] = (int address) { //SRL (IX/IY + offset), H
      _h = _srl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x3D] = (int address) { //SRL (IX/IY + offset), L
      _l = _srl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x3E] = (int address) { //SRL (IX/IY + offset)
      var value = _srl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x3F] = (int address) { //SRL (IX/IY + offset), A
      _a = _srl8(_machine.peek8(address));
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0x40] = //BIT 0, (IX/IY + offset)
    _opcodesDDFDCB[0x41] = _opcodesDDFDCB[0x42] = _opcodesDDFDCB[0x43] = _opcodesDDFDCB[0x44] = _opcodesDDFDCB[0x45] = _opcodesDDFDCB[0x46] = _opcodesDDFDCB[0x47] = (int address) {
      _bit(0x01, _machine.peek8(address));
      _f = (_f & _FLAGS_SZHPC) | ((address >> 8) & _FLAGS_53);
      _machine.contention(address, 1);
    };

    _opcodesDDFDCB[0x48] = //BIT 1, (IX/IY + offset)
    _opcodesDDFDCB[0x49] = _opcodesDDFDCB[0x4A] = _opcodesDDFDCB[0x4B] = _opcodesDDFDCB[0x4C] = _opcodesDDFDCB[0x4D] = _opcodesDDFDCB[0x4E] = _opcodesDDFDCB[0x4F] = (int address) {
      _bit(0x02, _machine.peek8(address));
      _f = (_f & _FLAGS_SZHPC) | ((address >> 8) & _FLAGS_53);
      _machine.contention(address, 1);
    };

    _opcodesDDFDCB[0x50] = //BIT 2, (IX/IY + offset)
    _opcodesDDFDCB[0x51] = _opcodesDDFDCB[0x52] = _opcodesDDFDCB[0x53] = _opcodesDDFDCB[0x54] = _opcodesDDFDCB[0x55] = _opcodesDDFDCB[0x56] = _opcodesDDFDCB[0x57] = (int address) {
      _bit(0x04, _machine.peek8(address));
      _f = (_f & _FLAGS_SZHPC) | ((address >> 8) & _FLAGS_53);
      _machine.contention(address, 1);
    };

    _opcodesDDFDCB[0x58] = //BIT 3, (IX/IY + offset)
    _opcodesDDFDCB[0x59] = _opcodesDDFDCB[0x5A] = _opcodesDDFDCB[0x5B] = _opcodesDDFDCB[0x5C] = _opcodesDDFDCB[0x5D] = _opcodesDDFDCB[0x5E] = _opcodesDDFDCB[0x5F] = (int address) {
      _bit(0x08, _machine.peek8(address));
      _f = (_f & _FLAGS_SZHPC) | ((address >> 8) & _FLAGS_53);
      _machine.contention(address, 1);
    };

    _opcodesDDFDCB[0x60] = //BIT 4, (IX/IY + offset)
    _opcodesDDFDCB[0x61] = _opcodesDDFDCB[0x62] = _opcodesDDFDCB[0x63] = _opcodesDDFDCB[0x64] = _opcodesDDFDCB[0x65] = _opcodesDDFDCB[0x66] = _opcodesDDFDCB[0x67] = (int address) {
      _bit(0x10, _machine.peek8(address));
      _f = (_f & _FLAGS_SZHPC) | ((address >> 8) & _FLAGS_53);
      _machine.contention(address, 1);
    };

    _opcodesDDFDCB[0x68] = //BIT 5, (IX/IY + offset)
    _opcodesDDFDCB[0x69] = _opcodesDDFDCB[0x6A] = _opcodesDDFDCB[0x6B] = _opcodesDDFDCB[0x6C] = _opcodesDDFDCB[0x6D] = _opcodesDDFDCB[0x6E] = _opcodesDDFDCB[0x6F] = (int address) {
      _bit(0x20, _machine.peek8(address));
      _f = (_f & _FLAGS_SZHPC) | ((address >> 8) & _FLAGS_53);
      _machine.contention(address, 1);
    };

    _opcodesDDFDCB[0x70] = //BIT 6, (IX/IY + offset)
    _opcodesDDFDCB[0x71] = _opcodesDDFDCB[0x72] = _opcodesDDFDCB[0x73] = _opcodesDDFDCB[0x74] = _opcodesDDFDCB[0x75] = _opcodesDDFDCB[0x76] = _opcodesDDFDCB[0x77] = (int address) {
      _bit(0x40, _machine.peek8(address));
      _f = (_f & _FLAGS_SZHPC) | ((address >> 8) & _FLAGS_53);
      _machine.contention(address, 1);
    };

    _opcodesDDFDCB[0x78] = //BIT 7, (IX/IY + offset)
    _opcodesDDFDCB[0x79] = _opcodesDDFDCB[0x7A] = _opcodesDDFDCB[0x7B] = _opcodesDDFDCB[0x7C] = _opcodesDDFDCB[0x7D] = _opcodesDDFDCB[0x7E] = _opcodesDDFDCB[0x7F] = (int address) {
      _bit(0x80, _machine.peek8(address));
      _f = (_f & _FLAGS_SZHPC) | ((address >> 8) & _FLAGS_53);
      _machine.contention(address, 1);
    };

    _opcodesDDFDCB[0x80] = (int address) { //RES 0, (IX/IY + offset), B
      _b = _machine.peek8(address) & 0xfe;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x81] = (int address) { //RES 0, (IX/IY + offset), C
      _c = _machine.peek8(address) & 0xfe;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x82] = (int address) { //RES 0, (IX/IY + offset), D
      _d = _machine.peek8(address) & 0xfe;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x83] = (int address) { //RES 0, (IX/IY + offset), E
      _e = _machine.peek8(address) & 0xfe;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x84] = (int address) { //RES 0, (IX/IY + offset), H
      _h = _machine.peek8(address) & 0xfe;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x85] = (int address) { //RES 0, (IX/IY + offset), L
      _l = _machine.peek8(address) & 0xfe;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x86] = (int address) { //RES 0, (IX/IY + offset)
      var value = _machine.peek8(address) & 0xfe;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x87] = (int address) { //RES 0, (IX/IY + offset), A
      _a = _machine.peek8(address) & 0xfe;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0x88] = (int address) { //RES 1, (IX/IY + offset), B
      _b = _machine.peek8(address) & 0xfd;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x89] = (int address) { //RES 1, (IX/IY + offset), C
      _c = _machine.peek8(address) & 0xfd;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x8A] = (int address) { //RES 1, (IX/IY + offset), D
      _d = _machine.peek8(address) & 0xfd;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x8B] = (int address) { //RES 1, (IX/IY + offset), E
      _e = _machine.peek8(address) & 0xfd;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x8C] = (int address) { //RES 1, (IX/IY + offset), H
      _h = _machine.peek8(address) & 0xfd;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x8D] = (int address) { //RES 1, (IX/IY + offset), L
      _l = _machine.peek8(address) & 0xfd;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x8E] = (int address) { //RES 1, (IX/IY + offset)
      var value = _machine.peek8(address) & 0xfd;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x8F] = (int address) { //RES 1, (IX/IY + offset), A
      _a = _machine.peek8(address) & 0xfd;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0x90] = (int address) { //RES 2, (IX/IY + offset), B
      _b = _machine.peek8(address) & 0xfb;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x91] = (int address) { //RES 2, (IX/IY + offset), C
      _c = _machine.peek8(address) & 0xfb;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x92] = (int address) { //RES 2, (IX/IY + offset), D
      _d = _machine.peek8(address) & 0xfb;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x93] = (int address) { //RES 2, (IX/IY + offset), E
      _e = _machine.peek8(address) & 0xfb;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x94] = (int address) { //RES 2, (IX/IY + offset), H
      _h = _machine.peek8(address) & 0xfb;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x95] = (int address) { //RES 2, (IX/IY + offset), L
      _l = _machine.peek8(address) & 0xfb;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x96] = (int address) { //RES 2, (IX/IY + offset)
      var value = _machine.peek8(address) & 0xfb;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x97] = (int address) { //RES 2, (IX/IY + offset), A
      _a = _machine.peek8(address) & 0xfb;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0x98] = (int address) { //RES 3, (IX/IY + offset), B
      _b = _machine.peek8(address) & 0xf7;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0x99] = (int address) { //RES 3, (IX/IY + offset), C
      _c = _machine.peek8(address) & 0xf7;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0x9A] = (int address) { //RES 3, (IX/IY + offset), D
      _d = _machine.peek8(address) & 0xf7;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0x9B] = (int address) { //RES 3, (IX/IY + offset), E
      _e = _machine.peek8(address) & 0xf7;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0x9C] = (int address) { //RES 3, (IX/IY + offset), H
      _h = _machine.peek8(address) & 0xf7;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0x9D] = (int address) { //RES 3, (IX/IY + offset), L
      _l = _machine.peek8(address) & 0xf7;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0x9E] = (int address) { //RES 3, (IX/IY + offset)
      var value = _machine.peek8(address) & 0xf7;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0x9F] = (int address) { //RES 3, (IX/IY + offset), A
      _a = _machine.peek8(address) & 0xf7;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xA0] = (int address) { //RES 4, (IX/IY + offset), B
      _b = _machine.peek8(address) & 0xef;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xA1] = (int address) { //RES 4, (IX/IY + offset), C
      _c = _machine.peek8(address) & 0xef;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xA2] = (int address) { //RES 4, (IX/IY + offset), D
      _d = _machine.peek8(address) & 0xef;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xA3] = (int address) { //RES 4, (IX/IY + offset), E
      _e = _machine.peek8(address) & 0xef;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xA4] = (int address) { //RES 4, (IX/IY + offset), H
      _h = _machine.peek8(address) & 0xef;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xA5] = (int address) { //RES 4, (IX/IY + offset), L
      _l = _machine.peek8(address) & 0xef;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xA6] = (int address) { //RES 4, (IX/IY + offset)
      var value = _machine.peek8(address) & 0xef;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xA7] = (int address) { //RES 4, (IX/IY + offset), A
      _a = _machine.peek8(address) & 0xef;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xA8] = (int address) { //RES 5, (IX/IY + offset), B
      _b = _machine.peek8(address) & 0xdf;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xA9] = (int address) { //RES 5, (IX/IY + offset), C
      _c = _machine.peek8(address) & 0xdf;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xAA] = (int address) { //RES 5, (IX/IY + offset), D
      _d = _machine.peek8(address) & 0xdf;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xAB] = (int address) { //RES 5, (IX/IY + offset), E
      _e = _machine.peek8(address) & 0xdf;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xAC] = (int address) { //RES 5, (IX/IY + offset), H
      _h = _machine.peek8(address) & 0xdf;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xAD] = (int address) { //RES 5, (IX/IY + offset), L
      _l = _machine.peek8(address) & 0xdf;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xAE] = (int address) { //RES 5, (IX/IY + offset)
      var value = _machine.peek8(address) & 0xdf;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xAF] = (int address) { //RES 5, (IX/IY + offset), A
      _a = _machine.peek8(address) & 0xdf;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xB0] = (int address) { //RES 6, (IX/IY + offset), B
      _b = _machine.peek8(address) & 0xbf;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xB1] = (int address) { //RES 6, (IX/IY + offset), C
      _c = _machine.peek8(address) & 0xbf;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xB2] = (int address) { //RES 6, (IX/IY + offset), D
      _d = _machine.peek8(address) & 0xbf;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xB3] = (int address) { //RES 6, (IX/IY + offset), E
      _e = _machine.peek8(address) & 0xbf;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xB4] = (int address) { //RES 6, (IX/IY + offset), H
      _h = _machine.peek8(address) & 0xbf;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xB5] = (int address) { //RES 6, (IX/IY + offset), L
      _l = _machine.peek8(address) & 0xbf;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xB6] = (int address) { //RES 6, (IX/IY + offset)
      var value = _machine.peek8(address) & 0xbf;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xB7] = (int address) { //RES 6, (IX/IY + offset), A
      _a = _machine.peek8(address) & 0xbf;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xB8] = (int address) { //RES 7, (IX/IY + offset), B
      _b = _machine.peek8(address) & 0x7f;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xB9] = (int address) { //RES 7, (IX/IY + offset), C
      _c = _machine.peek8(address) & 0x7f;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xBA] = (int address) { //RES 7, (IX/IY + offset), D
      _d = _machine.peek8(address) & 0x7f;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xBB] = (int address) { //RES 7, (IX/IY + offset), E
      _e = _machine.peek8(address) & 0x7f;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xBC] = (int address) { //RES 7, (IX/IY + offset), H
      _h = _machine.peek8(address) & 0x7f;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xBD] = (int address) { //RES /, (IX/IY + offset), L
      _l = _machine.peek8(address) & 0x7f;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xBE] = (int address) { //RES 7, (IX/IY + offset)
      var value = _machine.peek8(address) & 0x7f;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xBF] = (int address) { //RES 7, (IX/IY + offset), A
      _a = _machine.peek8(address) & 0x7f;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xC0] = (int address) { //SET 0, (IX/IY + offset), B
      _b = _machine.peek8(address) | 0x01;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xC1] = (int address) { //SET 0, (IX/IY + offset), C
      _c = _machine.peek8(address) | 0x01;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xC2] = (int address) { //SET 0, (IX/IY + offset), D
      _d = _machine.peek8(address) | 0x01;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xC3] = (int address) { //SET 0, (IX/IY + offset), E
      _e = _machine.peek8(address) | 0x01;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xC4] = (int address) { //SET 0, (IX/IY + offset), H
      _h = _machine.peek8(address) | 0x01;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xC5] = (int address) { //SET 0, (IX/IY + offset), L
      _l = _machine.peek8(address) | 0x01;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xC6] = (int address) { //SET 0, (IX/IY + offset)
      var value = _machine.peek8(address) | 0x01;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xC7] = (int address) { //SET 0, (IX/IY + offset), A
      _a = _machine.peek8(address) | 0x01;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xC8] = (int address) { //SET 1, (IX/IY + offset), B
      _b = _machine.peek8(address) | 0x02;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xC9] = (int address) { //SET 1, (IX/IY + offset), C
      _c = _machine.peek8(address) | 0x02;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xCA] = (int address) { //SET 1, (IX/IY + offset), D
      _d = _machine.peek8(address) | 0x02;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xCB] = (int address) { //SET 1, (IX/IY + offset), E
      _e = _machine.peek8(address) | 0x02;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xCC] = (int address) { //SET 1, (IX/IY + offset), H
      _h = _machine.peek8(address) | 0x02;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xCD] = (int address) { //SET 1, (IX/IY + offset), L
      _l = _machine.peek8(address) | 0x02;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xCE] = (int address) { //SET 1, (IX/IY + offset)
      var value = _machine.peek8(address) | 0x02;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xCF] = (int address) { //SET 1, (IX/IY + offset), A
      _a = _machine.peek8(address) | 0x02;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xD0] = (int address) { //SET 2, (IX/IY + offset), B
      _b = _machine.peek8(address) | 0x04;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xD1] = (int address) { //SET 2, (IX/IY + offset), C
      _c = _machine.peek8(address) | 0x04;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xD2] = (int address) { //SET 2, (IX/IY + offset), D
      _d = _machine.peek8(address) | 0x04;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xD3] = (int address) { //SET 2, (IX/IY + offset), E
      _e = _machine.peek8(address) | 0x04;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xD4] = (int address) { //SET 2, (IX/IY + offset), H
      _h = _machine.peek8(address) | 0x04;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xD5] = (int address) { //SET 2, (IX/IY + offset), L
      _l = _machine.peek8(address) | 0x04;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xD6] = (int address) { //SET 2, (IX/IY + offset)
      var value = _machine.peek8(address) | 0x04;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xD7] = (int address) { //SET 2, (IX/IY + offset), A
      _a = _machine.peek8(address) | 0x04;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xD8] = (int address) { //SET 3, (IX/IY + offset), B
      _b = _machine.peek8(address) | 0x08;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xD9] = (int address) { //SET 3, (IX/IY + offset), C
      _c = _machine.peek8(address) | 0x08;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xDA] = (int address) { //SET 3, (IX/IY + offset), D
      _d = _machine.peek8(address) | 0x08;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xDB] = (int address) { //SET 3, (IX/IY + offset), E
      _e = _machine.peek8(address) | 0x08;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xDC] = (int address) { //SET 3, (IX/IY + offset), H
      _h = _machine.peek8(address) | 0x08;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xDD] = (int address) { //SET 3, (IX/IY + offset), L
      _l = _machine.peek8(address) | 0x08;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xDE] = (int address) { //SET 3, (IX/IY + offset)
      var value = _machine.peek8(address) | 0x08;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xDF] = (int address) { //SET 3, (IX/IY + offset), A
      _a = _machine.peek8(address) | 0x08;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xE0] = (int address) { //SET 4, (IX/IY + offset), B
      _b = _machine.peek8(address) | 0x10;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xE1] = (int address) { //SET 4, (IX/IY + offset), C
      _c = _machine.peek8(address) | 0x10;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xE2] = (int address) { //SET 4, (IX/IY + offset), D
      _d = _machine.peek8(address) | 0x10;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xE3] = (int address) { //SET 4, (IX/IY + offset), E
      _e = _machine.peek8(address) | 0x10;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xE4] = (int address) { //SET 4, (IX/IY + offset), H
      _h = _machine.peek8(address) | 0x10;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xE5] = (int address) { //SET 4, (IX/IY + offset), L
      _l = _machine.peek8(address) | 0x10;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xE6] = (int address) { //SET 4, (IX/IY + offset)
      var value = _machine.peek8(address) | 0x10;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xE7] = (int address) { //SET 4, (IX/IY + offset), A
      _a = _machine.peek8(address) | 0x10;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xE8] = (int address) { //SET 5, (IX/IY + offset), B
      _b = _machine.peek8(address) | 0x20;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xE9] = (int address) { //SET 5, (IX/IY + offset), C
      _c = _machine.peek8(address) | 0x20;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xEA] = (int address) { //SET 5, (IX/IY + offset), D
      _d = _machine.peek8(address) | 0x20;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xEB] = (int address) { //SET 5, (IX/IY + offset), E
      _e = _machine.peek8(address) | 0x20;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xEC] = (int address) { //SET 5, (IX/IY + offset), H
      _h = _machine.peek8(address) | 0x20;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xED] = (int address) { //SET 5, (IX/IY + offset), L
      _l = _machine.peek8(address) | 0x20;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xEE] = (int address) { //SET 5, (IX/IY + offset)
      var value = _machine.peek8(address) | 0x20;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xEF] = (int address) { //SET 5, (IX/IY + offset), A
      _a = _machine.peek8(address) | 0x20;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xF0] = (int address) { //SET 6, (IX/IY + offset), B
      _b = _machine.peek8(address) | 0x40;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xF1] = (int address) { //SET 6, (IX/IY + offset), C
      _c = _machine.peek8(address) | 0x40;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xF2] = (int address) { //SET 6, (IX/IY + offset), D
      _d = _machine.peek8(address) | 0x40;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xF3] = (int address) { //SET 6, (IX/IY + offset), E
      _e = _machine.peek8(address) | 0x40;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xF4] = (int address) { //SET 6, (IX/IY + offset), H
      _h = _machine.peek8(address) | 0x40;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xF5] = (int address) { //SET 6, (IX/IY + offset), L
      _l = _machine.peek8(address) | 0x40;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xF6] = (int address) { //SET 6, (IX/IY + offset)
      var value = _machine.peek8(address) | 0x40;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xF7] = (int address) { //SET 6, (IX/IY + offset), A
      _a = _machine.peek8(address) | 0x40;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };

    _opcodesDDFDCB[0xF8] = (int address) { //SET 7, (IX/IY + offset), B
      _b = _machine.peek8(address) | 0x80;
      _machine.contention(address, 1);
      _machine.poke8(address, _b);
    };

    _opcodesDDFDCB[0xF9] = (int address) { //SET 6, (IX/IY + offset), C
      _c = _machine.peek8(address) | 0x80;
      _machine.contention(address, 1);
      _machine.poke8(address, _c);
    };

    _opcodesDDFDCB[0xFA] = (int address) { //SET 6, (IX/IY + offset), D
      _d = _machine.peek8(address) | 0x80;
      _machine.contention(address, 1);
      _machine.poke8(address, _d);
    };

    _opcodesDDFDCB[0xFB] = (int address) { //SET 6, (IX/IY + offset), E
      _e = _machine.peek8(address) | 0x80;
      _machine.contention(address, 1);
      _machine.poke8(address, _e);
    };

    _opcodesDDFDCB[0xFC] = (int address) { //SET 6, (IX/IY + offset), H
      _h = _machine.peek8(address) | 0x80;
      _machine.contention(address, 1);
      _machine.poke8(address, _h);
    };

    _opcodesDDFDCB[0xFD] = (int address) { //SET 6, (IX/IY + offset), L
      _l = _machine.peek8(address) | 0x80;
      _machine.contention(address, 1);
      _machine.poke8(address, _l);
    };

    _opcodesDDFDCB[0xFE] = (int address) { //SET 6, (IX/IY + offset)
      var value = _machine.peek8(address) | 0x80;
      _machine.contention(address, 1);
      _machine.poke8(address, value);
    };

    _opcodesDDFDCB[0xFF] = (int address) { //SET 6, (IX/IY + offset), A
      _a = _machine.peek8(address) | 0x80;
      _machine.contention(address, 1);
      _machine.poke8(address, _a);
    };
  }

  void _initFlags() {
    for (var i = 0; i < 256; ++i) {
      _sz53n_add[i] = (i > 0x7f ? _FLAG_S : 0) | (i & _FLAGS_53);
      _sz53n_sub[i] = _sz53n_add[i] | _FLAG_N;

      var even = true;
      for (var mask = 0x01; mask < 0x100; mask <<= 1) {
        if ((i & mask) != 0) {
          even = !even;
        }
      }

      _sz53pn_add[i] = _sz53n_add[i] | (even ? _FLAG_P : 0);
      _sz53pn_sub[i] = _sz53n_sub[i] | (even ? _FLAG_P : 0);
    }

    _sz53n_add[0] |= _FLAG_Z;
    _sz53pn_add[0] |= _FLAG_Z;
    _sz53n_sub[0] |= _FLAG_Z;
    _sz53pn_sub[0] |= _FLAG_Z;
  }
}
