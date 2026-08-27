import 'package:flutter/widgets.dart';
import 'store.dart';
import 'lang.dart';

const white = Color(0xFFFFFFFF);
const clear = Color(0x00000000);

class Pal {
  final bool dark;
  const Pal(this.dark);
  Pal get pal => this;
  Color get bg => dark ? const Color(0xFF0C0E11) : const Color(0xFFF6F7F9);
  Color get surface => dark ? const Color(0xFF15181D) : const Color(0xFFFFFFFF);
  Color get surface2 =>
      dark ? const Color(0xFF1E2228) : const Color(0xFFF0F2F4);
  Color get line => dark ? const Color(0xFF2B3138) : const Color(0xFFDDE2E7);
  Color get text => dark ? const Color(0xFFF2F4F6) : const Color(0xFF171A1E);
  Color get text2 => dark ? const Color(0xFFB6BDC7) : const Color(0xFF535D68);
  Color get sub => dark ? const Color(0xFF808995) : const Color(0xFF7B8692);
  Color get accent => dark ? const Color(0xFF8DA4FF) : const Color(0xFF4D68F6);
  Color get accentSoft =>
      dark ? const Color(0xFF232D55) : const Color(0xFFEEF1FF);
  Color get bad => dark ? const Color(0xFFFF7F7F) : const Color(0xFFC34A4A);
}

class ThemeScope extends InheritedWidget {
  final Pal pal;
  const ThemeScope({super.key, required this.pal, required super.child});
  static Pal of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<ThemeScope>()!.pal;
  @override
  bool updateShouldNotify(ThemeScope old) => old.pal.dark != pal.dark;
}

TextStyle title(Pal p, {double s = 27}) => TextStyle(
    color: p.text,
    fontSize: s,
    fontWeight: FontWeight.w700,
    letterSpacing: -.5);
TextStyle body(Pal p, {double s = 14, FontWeight w = FontWeight.w400}) =>
    TextStyle(color: p.text2, fontSize: s, fontWeight: w, height: 1.4);
TextStyle cap(Pal p) =>
    TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w500);

BoxDecoration box(Pal p, {double r = 16}) => BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: p.line),
      boxShadow: p.dark
          ? null
          : const [
              BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 18,
                  offset: Offset(0, 7))
            ],
    );

class IconX extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const IconX(this.name, {super.key, this.size = 20, this.color});
  @override
  Widget build(BuildContext c) => CustomPaint(
      size: Size.square(size),
      painter: _Painter(name, color ?? ThemeScope.of(c).pal.text));
}

class _Painter extends CustomPainter {
  final String n;
  final Color c;
  _Painter(this.n, this.c);
  @override
  void paint(Canvas g, Size s) {
    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final f = Paint()
      ..color = c
      ..style = PaintingStyle.fill;
    final w = s.width, h = s.height;
    void l(double x1, double y1, double x2, double y2) =>
        g.drawLine(Offset(x1, y1), Offset(x2, y2), p);
    switch (n) {
      case 'home':
        g.drawPath(
            Path()
              ..moveTo(w * .15, h * .48)
              ..lineTo(w * .5, h * .2)
              ..lineTo(w * .85, h * .48),
            p);
        g.drawRRect(
            RRect.fromLTRBR(
                w * .25, h * .43, w * .75, h * .82, const Radius.circular(2)),
            p);
        break;
      case 'tag':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .18, h * .26, w * .82, h * .74, const Radius.circular(3)),
            p);
        l(w * .32, h * .5, w * .68, h * .5);
        break;
      case 'clock':
        g.drawCircle(Offset(w / 2, h / 2), w * .32, p);
        l(w / 2, h / 2, w / 2, h * .3);
        l(w / 2, h / 2, w * .65, h * .56);
        break;
      case 'note':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .23, h * .15, w * .77, h * .85, const Radius.circular(3)),
            p);
        l(w * .35, h * .38, w * .65, h * .38);
        l(w * .35, h * .53, w * .65, h * .53);
        l(w * .35, h * .68, w * .56, h * .68);
        break;
      case 'settings':
        l(w * .18, h * .3, w * .82, h * .3);
        l(w * .18, h * .5, w * .82, h * .5);
        l(w * .18, h * .7, w * .82, h * .7);
        g.drawCircle(Offset(w * .62, h * .3), w * .055, f);
        g.drawCircle(Offset(w * .38, h * .5), w * .055, f);
        g.drawCircle(Offset(w * .58, h * .7), w * .055, f);
        break;
      case 'info':
        g.drawCircle(Offset(w / 2, h / 2), w * .32, p);
        g.drawCircle(Offset(w / 2, h * .36), w * .025, f);
        l(w / 2, h * .48, w / 2, h * .69);
        break;
      case 'plus':
        l(w * .5, h * .22, w * .5, h * .78);
        l(w * .22, h * .5, w * .78, h * .5);
        break;
      case 'minus':
        l(w * .22, h * .5, w * .78, h * .5);
        break;
      case 'x':
        l(w * .27, h * .27, w * .73, h * .73);
        l(w * .73, h * .27, w * .27, h * .73);
        break;
      case 'check':
        l(w * .2, h * .53, w * .42, h * .74);
        l(w * .42, h * .74, w * .82, h * .29);
        break;
      case 'left':
        l(w * .62, h * .25, w * .36, h * .5);
        l(w * .36, h * .5, w * .62, h * .75);
        break;
      case 'right':
        l(w * .38, h * .25, w * .64, h * .5);
        l(w * .64, h * .5, w * .38, h * .75);
        break;
      case 'folder':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .13, h * .3, w * .87, h * .78, const Radius.circular(2)),
            p);
        l(w * .14, h * .42, w * .43, h * .42);
        l(w * .43, h * .42, w * .49, h * .3);
        break;
      case 'pin':
        g.drawCircle(Offset(w * .5, h * .34), w * .14, p);
        l(w * .5, h * .48, w * .5, h * .82);
        break;
      case 'trash':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .28, h * .29, w * .72, h * .82, const Radius.circular(2)),
            p);
        l(w * .22, h * .25, w * .78, h * .25);
        l(w * .42, h * .18, w * .58, h * .18);
        l(w * .42, h * .18, w * .42, h * .25);
        l(w * .58, h * .18, w * .58, h * .25);
        break;
      case 'play':
        g.drawPath(
            Path()
              ..moveTo(w * .36, h * .25)
              ..lineTo(w * .74, h * .5)
              ..lineTo(w * .36, h * .75)
              ..close(),
            f);
        break;
      case 'pause':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .3, h * .25, w * .43, h * .75, const Radius.circular(1)),
            f);
        g.drawRRect(
            RRect.fromLTRBR(
                w * .57, h * .25, w * .7, h * .75, const Radius.circular(1)),
            f);
        break;
      case 'refresh':
        g.drawArc(Rect.fromCircle(center: Offset(w / 2, h / 2), radius: w * .3),
            -.8, 4.7, false, p);
        l(w * .75, h * .26, w * .75, h * .43);
        l(w * .75, h * .26, w * .58, h * .29);
        break;
      case 'bolt':
        g.drawPath(
            Path()
              ..moveTo(w * .57, h * .12)
              ..lineTo(w * .3, h * .54)
              ..lineTo(w * .48, h * .54)
              ..lineTo(w * .41, h * .88)
              ..lineTo(w * .71, h * .42)
              ..lineTo(w * .53, h * .42)
              ..close(),
            f);
        break;
      case 'target':
        g.drawCircle(Offset(w / 2, h / 2), w * .32, p);
        g.drawCircle(Offset(w / 2, h / 2), w * .20, p);
        g.drawCircle(Offset(w / 2, h / 2), w * .06, f);
        l(w * .78, h * .22, w * .58, h * .42);
        break;
      case 'more':
        g.drawCircle(Offset(w * .25, h * .5), w * .07, f);
        g.drawCircle(Offset(w * .5, h * .5), w * .07, f);
        g.drawCircle(Offset(w * .75, h * .5), w * .07, f);
        break;
      case 'moreV':
        g.drawCircle(Offset(w * .5, h * .25), w * .07, f);
        g.drawCircle(Offset(w * .5, h * .5), w * .07, f);
        g.drawCircle(Offset(w * .5, h * .75), w * .07, f);
        break;
      case 'calendar':
        g.drawRRect(
            RRect.fromLTRBR(
                w * .18, h * .22, w * .82, h * .82, const Radius.circular(3)),
            p);
        l(w * .18, h * .38, w * .82, h * .38);
        l(w * .34, h * .14, w * .34, h * .30);
        l(w * .66, h * .14, w * .66, h * .30);
        break;
      default:
        g.drawCircle(Offset(w / 2, h / 2), w * .25, p);
    }
  }

  @override
  bool shouldRepaint(covariant _Painter old) => old.n != n || old.c != c;
}

class Btn extends StatelessWidget {
  final Widget child;
  final VoidCallback? on;
  final bool filled;
  final EdgeInsets pad;
  final double radius;
  const Btn(
      {super.key,
      required this.child,
      this.on,
      this.filled = false,
      this.pad = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      this.radius = 10});
  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: on,
        child: Container(
            padding: pad,
            decoration: BoxDecoration(
                color: filled ? p.accent : clear,
                borderRadius: BorderRadius.circular(radius)),
            child: child));
  }
}

class IconBtn extends StatelessWidget {
  final String icon;
  final VoidCallback? on;
  final double size;
  const IconBtn({super.key, required this.icon, this.on, this.size = 19});
  @override
  Widget build(BuildContext c) => Btn(
      on: on,
      pad: const EdgeInsets.all(8),
      child: IconX(icon, size: size, color: ThemeScope.of(c).pal.text2));
}

class Field extends StatefulWidget {
  final TextEditingController ctrl;
  final String? hint;
  final String? label;
  final TextInputType? type;
  final int maxLines;
  const Field(
      {super.key,
      required this.ctrl,
      this.hint,
      this.label,
      this.type,
      this.maxLines = 1});
  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  final FocusNode node = FocusNode();
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_changed);
    node.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_changed);
    node.removeListener(_changed);
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final active = node.hasFocus;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: node.requestFocus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: active ? p.accent : p.line, width: active ? 1.2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.label != null) Text(widget.label!, style: cap(p)),
          if (widget.label != null) const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: Stack(children: [
              if (widget.ctrl.text.isEmpty && widget.hint != null)
                Text(widget.hint!, style: body(p)),
              EditableText(
                controller: widget.ctrl,
                focusNode: node,
                style: TextStyle(color: p.text, fontSize: 14),
                cursorColor: p.accent,
                backgroundCursorColor: p.sub,
                keyboardType: widget.type,
                maxLines: widget.maxLines,
                minLines: widget.maxLines > 1 ? widget.maxLines : null,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class Progress extends StatelessWidget {
  final double value;
  const Progress({super.key, required this.value});
  @override
  Widget build(BuildContext context) {
    final p = ThemeScope.of(context).pal;
    final v = value.clamp(0.0, 1.0).toDouble();
    return Container(
      height: 6,
      decoration: BoxDecoration(
          color: p.surface2, borderRadius: BorderRadius.circular(99)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: v,
        child: Container(
            decoration: BoxDecoration(
                color: p.accent, borderRadius: BorderRadius.circular(99))),
      ),
    );
  }
}

class Header extends StatelessWidget {
  final String titleText;
  final String? sub;
  final bool back;
  final List<Widget> actions;
  const Header(
      {super.key,
      required this.titleText,
      this.sub,
      this.back = false,
      this.actions = const []});
  @override
  Widget build(BuildContext c) {
    final p = ThemeScope.of(c).pal;
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 15),
        child: Row(children: [
          if (back) IconBtn(icon: 'left', on: nav.back),
          if (back) const SizedBox(width: 7),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(titleText, style: title(p)),
                if (sub != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(sub!, style: cap(p)))
              ])),
          ...actions
        ]));
  }
}

class Section extends StatelessWidget {
  final String text;
  const Section(this.text, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(),
          style: cap(ThemeScope.of(c).pal)
              .copyWith(fontSize: 10, letterSpacing: 1.2)));
}

Future<T?> sheet<T>(BuildContext context, Widget child) {
  final pal = ThemeScope.of(context).pal;
  return Navigator.of(context).push<T>(PageRouteBuilder<T>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: const Color(0x88000000),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, animation, __) =>
        _Sheet(pal: pal, child: child, animation: animation),
  ));
}

class _Sheet extends StatelessWidget {
  final Pal pal;
  final Widget child;
  final Animation<double> animation;
  const _Sheet(
      {required this.pal, required this.child, required this.animation});
  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
                color: p.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: p.line))),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: p.line,
                        borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 14),
                ThemeScope(pal: p, child: child),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> confirm(
    BuildContext context, String titleText, String message) async {
  final pal = ThemeScope.of(context).pal;
  final result = await Navigator.of(context).push<bool>(PageRouteBuilder<bool>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: const Color(0x99000000),
    pageBuilder: (_, __, ___) => ThemeScope(
        pal: pal,
        child: Center(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: _Confirm(
                    pal: pal, titleText: titleText, message: message)))),
  ));
  return result ?? false;
}

class _Confirm extends StatelessWidget {
  final Pal pal;
  final String titleText;
  final String message;
  const _Confirm(
      {required this.pal, required this.titleText, required this.message});
  @override
  Widget build(BuildContext context) {
    final p = pal;
    return Container(
      constraints: const BoxConstraints(maxWidth: 430),
      padding: const EdgeInsets.all(22),
      decoration: box(p, r: 18),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titleText, style: title(p, s: 19)),
            const SizedBox(height: 8),
            Text(message, style: body(p)),
            const SizedBox(height: 19),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Btn(
                  on: () => Navigator.pop(context, false),
                  child:
                      Text(L.t('cancel'), style: body(p, w: FontWeight.w600))),
              const SizedBox(width: 7),
              Btn(
                  filled: true,
                  on: () => Navigator.pop(context, true),
                  child: const Text('OK',
                      style: TextStyle(
                          color: white, fontWeight: FontWeight.w700))),
            ]),
          ]),
    );
  }
}
