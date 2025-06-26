import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/file_service.dart';
import '../services/pdf_parser.dart';
import '../services/vector_store.dart';
import '../services/llm_service.dart';
import '../models/document_model.dart';
import 'chat_screen.dart';
import 'pdf_list_screen.dart';
import '../widgets/loading_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  List<DocumentModel> _documents = [];
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing services...';
    });

    try {
      final vectorStore = context.read<VectorStore>();
      final llmService = context.read<LlmService>();
      
      await vectorStore.initialize();
      await llmService.initialize();
      
      await _loadDocuments();
      
      setState(() {
        _statusMessage = 'Ready to use!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDocuments() async {
    try {
      final vectorStore = context.read<VectorStore>();
      final documents = await vectorStore.getAllDocuments();
      setState(() {
        _documents = documents;
      });
    } catch (e) {
      print('Error loading documents: $e');
    }
  }

  Future<void> _addDocument() async {
    final fileService = context.read<FileService>();
    final pdfParser = context.read<PdfParser>();
    final vectorStore = context.read<VectorStore>();

    setState(() {
      _isLoading = true;
      _statusMessage = 'Selecting PDF file...';
    });

    try {
      // Pick PDF file
      final file = await fileService.pickPdfFile();
      if (file == null) {
        setState(() {
          _statusMessage = 'No file selected';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Validating PDF...';
      });

      // Validate PDF
      final isValid = await pdfParser.isValidPdf(file.path);
      if (!isValid) {
        setState(() {
          _statusMessage = 'Invalid PDF file';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Saving PDF...';
      });

      // Save PDF to app directory
      final fileName = fileService.getFileName(file.path);
      final savedPath = await fileService.savePdfFile(file, fileName);
      if (savedPath == null) {
        setState(() {
          _statusMessage = 'Failed to save PDF';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Extracting text...';
      });

      // Extract text
      final content = await pdfParser.extractTextFromPdf(savedPath);
      if (content.isEmpty) {
        setState(() {
          _statusMessage = 'No text found in PDF';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Creating document chunks...';
      });

      // Create document
      final documentId = DateTime.now().millisecondsSinceEpoch.toString();
      final chunks = pdfParser.splitTextIntoChunks(documentId, content);
      
      final document = DocumentModel(
        id: documentId,
        name: fileName,
        path: savedPath,
        content: content,
        createdAt: DateTime.now(),
        chunks: chunks,
      );

      setState(() {
        _statusMessage = 'Generating embeddings...';
      });

      // Generate embeddings
      final documentWithEmbeddings = await vectorStore.generateEmbeddings(document);

      setState(() {
        _statusMessage = 'Storing document...';
      });

      // Store in vector database
      await vectorStore.storeDocument(documentWithEmbeddings);

      setState(() {
        _statusMessage = 'Document added successfully!';
      });

      // Reload documents
      await _loadDocuments();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added document: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error adding document: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showApiSettings() async {
    final llmService = context.read<LlmService>();
    final currentConfig = llmService.currentConfig;
    
    String apiKey = '';
    String provider = currentConfig['provider'] ?? 'groq';
    String model = currentConfig['model'] ?? 'llama3-8b-8192';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _ApiSettingsDialog(
        initialProvider: provider,
        initialModel: model,
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Testing API connection...';
      });

      try {
        await llmService.setApiConfig(
          result['apiKey']!,
          result['provider']!,
          result['model']!,
        );

        final isConnected = await llmService.testApiConnection();
        setState(() {
          _statusMessage = isConnected 
              ? 'API configured successfully!'
              : 'API configuration saved (connection test failed)';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isConnected 
                  ? 'API configured successfully!'
                  : 'API saved but connection test failed'),
              backgroundColor: isConnected ? Colors.green : Colors.orange,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _statusMessage = 'Error configuring API: $e';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RAG AI Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showApiSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading) ...[
                      const LoadingIndicator(),
                      const SizedBox(height: 8),
                    ],
                    Text(_statusMessage),
                    const SizedBox(height: 8),
                    Text(
                      'Documents: ${_documents.length}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _addDocument,
              icon: const Icon(Icons.add),
              label: const Text('Add PDF Document'),
            ),
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _documents.isEmpty ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('Start Chat'),
            ),
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _documents.isEmpty ? null : () {
                Navigator.push(
                  context,
