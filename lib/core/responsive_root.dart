import 'package:flutter/material.dart';

import '../features/home/home_shell.dart';
import '../features/web/web_terminal_shell.dart';

class ResponsiveRoot extends StatelessWidget {
  const ResponsiveRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          // Unique Web/Desktop Trading Terminal
          return const WebTerminalShell();
        }
        
        // Classic Mobile App layout
        return const HomeShell();
      },
    );
  }
}
