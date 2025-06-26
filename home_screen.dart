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
  double? _progressValue; // For LinearProgressIndicator
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
        _progressValue = null; // Ensure progress is cleared on completion or error
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
      _progressValue = null; // Reset progress
    });

    try {
      // Pick PDF file
      final file = await fileService.pickPdfFile();
      if (file == null) {
        setState(() {
          _statusMessage = 'No file selected';
          _isLoading = false;
          _progressValue = null;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Validating PDF...';
        _progressValue = null;
      });

      // Validate PDF
      final isValid = await pdfParser.isValidPdf(file.path);
      if (!isValid) {
        setState(() {
          _statusMessage = 'Invalid PDF file';
          _isLoading = false;
          _progressValue = null;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Saving PDF...';
        _progressValue = null;
      });

      // Save PDF to app directory
      final fileName = fileService.getFileName(file.path);
      final savedPath = await fileService.savePdfFile(file, fileName);
      if (savedPath == null) {
        setState(() {
          _statusMessage = 'Failed to save PDF';
          _isLoading = false;
          _progressValue = null;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Extracting text...';
        _progressValue = 0.0; // Start progress for extraction
      });

      // Extract text
      String content = '';
      try {
        content = await pdfParser.extractTextFromPdf(
          savedPath,
          onProgress: (currentPage, totalPages) {
            setState(() {
              _statusMessage = 'Extracting text... Page $currentPage of $totalPages';
              _progressValue = totalPages > 0 ? currentPage / totalPages : 0.0;
            });
          },
        );
      } catch (e) {
        setState(() {
          _statusMessage = 'Error extracting text: $e';
          _isLoading = false;
          _progressValue = null;
        });
        return;
      }

      if (content.isEmpty) {
        setState(() {
          _statusMessage = 'No text found in PDF';
          _isLoading = false;
          _progressValue = null;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Creating document chunks...';
        _progressValue = null; // Reset for next step or hide
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
        _progressValue = 0.0; // Start progress for embeddings
      });

      // Generate embeddings
      DocumentModel documentWithEmbeddings;
      try {
        documentWithEmbeddings = await vectorStore.generateEmbeddings(
          document,
          onProgress: (currentChunk, totalChunks) {
            setState(() {
              _statusMessage = 'Generating embeddings... Chunk $currentChunk of $totalChunks';
              _progressValue = totalChunks > 0 ? currentChunk / totalChunks : 0.0;
            });
          },
        );
      } catch (e) {
        setState(() {
          _statusMessage = 'Error generating embeddings: $e';
          _isLoading = false;
          _progressValue = null;
        });
        return;
      }

      setState(() {
        _statusMessage = 'Storing document...';
        _progressValue = null; // Done with progress for this operation
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
                      if (_progressValue != null)
                        LinearProgressIndicator(value: _progressValue)
                      else
                        const LoadingIndicator(), // Existing indeterminate indicator
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
