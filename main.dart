import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/file_service.dart';
import 'services/pdf_parser.dart';
import 'services/embedding_service.dart';
import 'services/vector_store.dart';
import 'services/llm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FileService>(create: (_) => FileService()),
        Provider<PdfParser>(create: (_) => PdfParser()),
        Provider<EmbeddingService>(create: (_) => EmbeddingService()),
        Provider<VectorStore>(create: (_) => VectorStore()),
        Provider<LlmService>(create: (_) => LlmService()),
      ],
      child: MaterialApp(
        title: 'RAG AI Reader',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
