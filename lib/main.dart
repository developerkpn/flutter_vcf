import 'package:flutter/material.dart';
import 'package:flutter_vcf/config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  AppConfig.logResolvedConfig();
  runApp(const VCFApp());
}

class VCFApp extends StatelessWidget {
  const VCFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Card Form',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
