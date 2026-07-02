import 'package:flutter/material.dart';

import 'flutter_nav.dart';

/// Pop inner route or close Flutter Activity when this is the root screen.
void popProfileOrClose(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    closeFlutterPlay();
  }
}
