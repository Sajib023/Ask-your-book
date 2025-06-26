import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/document_model.dart';

class PdfParser {
  /// Extract text content from a PDF file
  Future<String> extractTextFromPdf(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('PDF file not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      
      String extractedText = '';
      final textExtractor = PdfTextExtractor(document);
      
      for (int i = 0; i < document.pages.count; i++) {
        final pageText = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
        extractedText += pageText;
        
        // Add page separator
        if (i < document.pages.count - 1) {
          extractedText += '\n\n--- Page ${i + 2} ---\n\n';
        }
      }
      
      document.dispose();
      
      return extractedText.trim();
    } catch (e) {
      print('Error extracting text from PDF: $e');
      throw Exception('Failed to extract text from PDF: $e');
    }
  }

  /// Split text into chunks for embedding
  List<DocumentChunk> splitTextIntoChunks(
    String documentId,
    String text, {
    int chunkSize = 500,
    int overlap = 50,
  }) {
    if (text.isEmpty) {
      return [];
    }

    final chunks = <DocumentChunk>[];
    final sentences = _splitIntoSentences(text);
    
    String currentChunk = '';
    int startIndex = 0;
    int chunkIndex = 0;
    
    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final potentialChunk = currentChunk.isEmpty 
          ? sentence 
          : '$currentChunk $sentence';
      
      if (potentialChunk.length <= chunkSize || currentChunk.isEmpty) {
        currentChunk = potentialChunk;
      } else {
        // Create chunk from current content
        if (currentChunk.isNotEmpty) {
          final chunk = DocumentChunk(
            id: '${documentId}_chunk_$chunkIndex',
            documentId: documentId,
            content: currentChunk.trim(),
            startIndex: startIndex,
            endIndex: startIndex + currentChunk.length,
          );
          chunks.add(chunk);
          chunkIndex++;
          
          // Handle overlap
          if (overlap > 0 && currentChunk.length > overlap) {
            final overlapText = currentChunk.substring(currentChunk.length - overlap);
            startIndex = startIndex + currentChunk.length - overlap;
            currentChunk = '$overlapText $sentence';
          } else {
            startIndex = startIndex + currentChunk.length;
            currentChunk = sentence;
          }
        }
      }
    }
    
    // Add the last chunk if it exists
    if (currentChunk.isNotEmpty) {
      final chunk = DocumentChunk(
        id: '${documentId}_chunk_$chunkIndex',
        documentId: documentId,
        content: currentChunk.trim(),
        startIndex: startIndex,
        endIndex: startIndex + currentChunk.length,
      );
      chunks.add(chunk);
    }
    
    return chunks;
  }

  /// Split text into sentences
  List<String> _splitIntoSentences(String text) {
    // Simple sentence splitting - can be improved with more sophisticated NLP
    final sentences = text
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 10) // Filter out very short fragments
        .toList();
    
    return sentences;
  }

  /// Get PDF metadata
  Future<Map<String, dynamic>> getPdfMetadata(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('PDF file not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      
      final metadata = <String, dynamic>{
        'pageCount': document.pages.count,
        'fileSize': bytes.length,
        'title': document.documentInformation.title ?? '',
        'author': document.documentInformation.author ?? '',
        'subject': document.documentInformation.subject ?? '',
        'creator': document.documentInformation.creator ?? '',
        'creationDate': document.documentInformation.creationDate?.toString() ?? '',
        'modificationDate': document.documentInformation.modificationDate?.toString() ?? '',
      };
      
      document.dispose();
      
      return metadata;
    } catch (e) {
      print('Error getting PDF metadata: $e');
      return {};
    }
  }

  /// Validate if file is a valid PDF
  Future<bool> isValidPdf(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final bytes = await file.readAsBytes();
      
      // Check PDF header
      if (bytes.length < 5) {
        return false;
      }
      
      final header = String.fromCharCodes(bytes.take(4));
      if (header != '%PDF') {
        return false;
      }
      
      // Try to open the document
      final document = PdfDocument(inputBytes: bytes);
      final isValid = document.pages.count > 0;
      document.dispose();
      
      return isValid;
    } catch (e) {
      print('Error validating PDF: $e');
      return false;
    }
  }

  /// Extract text from specific page
  Future<String> extractTextFromPage(String filePath, int pageIndex) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('PDF file not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      
      if (pageIndex >= document.pages.count || pageIndex < 0) {
        document.dispose();
        throw Exception('Invalid page index: $pageIndex');
      }
      
      final textExtractor = PdfTextExtractor(document);
      final pageText = textExtractor.extractText(
        startPageIndex: pageIndex, 
        endPageIndex: pageIndex
      );
      
      document.dispose();
      
      return pageText.trim();
    } catch (e) {
      print('Error extracting text from page: $e');
      throw Exception('Failed to extract text from page: $e');
    }
  }
}
