import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/player_state.dart';
import 'screens/room_screen.dart';

void main() {
  runApp(const OblezApp());
}

class OblezApp extends StatelessWidget {
  const OblezApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlayerState(),
      child: MaterialApp(
        title: 'أوبلز',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const RoomScreen(),
        ),
      ),
    );
  }
}
