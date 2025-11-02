import 'package:flutter/material.dart';
class AnimatedToggle extends StatefulWidget {
  final List<dynamic> text;
  final List<dynamic> buttonText;
  final ValueChanged onToggleCallback;
  final Color onColor;
  final Color offColor;
  final Color backgroundColor;
  int position;
  double hight;
  double width;

  final textColor = Colors.white;

  AnimatedToggle({
    required this.text,
    required this.buttonText,
    required this.onColor,
    required this.offColor,
    required this.backgroundColor,
    required this.position,
    required this.onToggleCallback,
    required this.hight,
    required this.width

  });
  @override
  _AnimatedToggleState createState() => _AnimatedToggleState();
}

class _AnimatedToggleState extends State<AnimatedToggle> {
  bool initialPosition = false;
  @override
  Widget build(BuildContext context) {
    initialPosition = widget.position == 1?true : false;
    double width = widget.width;
    return Container(
      margin: EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          GestureDetector(
            onTap: () {
              initialPosition = widget.position == 1?true : false;
              var index = 0;
              if (!initialPosition) {
                index = 1;
              }
              widget.onToggleCallback(index);
              setState(() {});
            },
            child: Container(
              height: width * 0.155,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(width * 0.1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  widget.text.length,
                      (index) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.1),
                    child: Text(
                      widget.text[index],
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: width * 0.05,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF918f95),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: EdgeInsets.all(5),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.decelerate,
              alignment:
              !initialPosition ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: width * 0.5,
                height: width * 0.13,
                decoration: ShapeDecoration(
                  color: !initialPosition ?widget.offColor : widget.onColor,
                  shadows: null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(width * 0.1),
                  ),
                ),
                child: Text(
                  initialPosition ? widget.buttonText[1] : widget.buttonText[0],
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: width * 0.045,
                    color: widget.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                alignment: Alignment.center,
              ),
            ),),
        ],
      ),
    );
  }
}

class ConnectButton extends StatefulWidget {
  final List<dynamic> text;
  final List<dynamic> buttonText;
  final ValueChanged onToggleCallback;
  final Color onColor;
  final Color offColor;
  bool position;

  final backgroundColor = Color(0xFF292636);
  final textColor = Colors.white;

  ConnectButton({
    required this.text,
    required this.buttonText,
    required this.onToggleCallback,
    required this.onColor,
    required this.offColor,
    required this.position,
  });
  @override
  _ConnectButtonState createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> {
  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.all(20),
      child: Stack(
        children: <Widget>[
          GestureDetector(
            onTap: () {
              var index = 1;
              if (widget.position) {
                index = 0;
              }
              widget.onToggleCallback(index);
              setState(() {});
            },
            child: Container(
              width: width,
              height: width * 0.155,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(width * 0.1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  widget.text.length,
                      (index) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.1),
                    child: Text(
                      widget.text[index],
                      style: TextStyle(
                        fontFamily: 'Rubik',
                        fontSize: width * 0.05,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF918f95),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: EdgeInsets.all(5),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.decelerate,
              alignment:
              //!initialPosition ? Alignment.centerLeft : Alignment.centerRight,
              !widget.position ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                width: width * 0.5,
                height: width * 0.13,
                decoration: ShapeDecoration(
                  color: widget.position ?widget.offColor : widget.onColor,
                  shadows: null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(width * 0.1),
                  ),
                ),
                child: Text(
                  !widget.position ? widget.buttonText[0] : widget.buttonText[1],
                  style: TextStyle(
                    fontFamily: 'Rubik',
                    fontSize: width * 0.045,
                    color: widget.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                alignment: Alignment.center,
              ),
            ),),
        ],
      ),
    );
  }
}