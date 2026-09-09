import 'package:flutter/material.dart';

void main() {
  runApp(const BlistraApp());
}

class BlistraApp extends StatelessWidget {
  const BlistraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blistra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const BlistraHomePage(),
    );
  }
}

class BlistraHomePage extends StatelessWidget {
  const BlistraHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blistra'),
      ),
      body: const Center(
        child: Text(
          'Everything you need. One app.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}