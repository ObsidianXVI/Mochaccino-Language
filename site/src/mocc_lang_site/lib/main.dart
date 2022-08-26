import 'package:flutter/material.dart';

void main() {
  runApp(App());
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/data',
      onUnknownRoute: (RouteSettings settings) {},
      routes: <String, WidgetBuilder>{'/': (BuildContext context) {}},
    );
  }
}
