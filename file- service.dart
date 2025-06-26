import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FileService {
  static const String _documentsFolder = 'rag_documents';

  /// Initialize the file service and create necessary directories
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory('${appDir.path}/$_documentsFolder');
    
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
  }

  /// Request storage permissions
  Future<bool> requestPermissions() async {
    var status = await Permission.storage.status;
    if (status.isDenied) {
      status = await Permission.storage.request();
    }
    
    if (status.isPermanentlyDenied) {
      openAppSettings();
      return false;
    }
    
    return status.isGranted;
  }

  /// Pick a PDF file from device storage
  Future<File?> pickPdfFile() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        return null;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
      return null;
    } catch (e) {
      print('Error picking PDF file: $e');
      return null;
    }
  }

  /// Save a PDF file to the app's documents directory
  Future<String?> savePdfFile(File sourceFile, String fileName) async {
    try {
      await initialize();
      
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory('${appDir.path}/$_documentsFolder');
      
      // Ensure unique filename
      String uniqueFileName = fileName;
      int counter = 1;
      while (await File('${docsDir.path}/$uniqueFileName').exists()) {
        final nameWithoutExt = fileName.replaceAll('.pdf', '');
        uniqueFileName = '${nameWithoutExt}_$counter.pdf';
        counter++;
      }
      
      final destinationPath = '${docsDir.path}/$uniqueFileName';
      final copiedFile = await sourceFile.copy(destinationPath);
      
      return copiedFile.path;
    } catch (e) {
      print('Error saving PDF file: $e');
      return null;
    }
  }

  /// Get all PDF files from the app's documents directory
  Future<List<File>> getSavedPdfFiles() async {
    try {
      await initialize();
      
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory('${appDir.path}/$_documentsFolder');
      
      if (!await docsDir.exists()) {
        return [];
      }
      
      final files = await docsDir.list().toList();
      return files
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.pdf'))
          .toList();
    } catch (e) {
      print('Error getting saved PDF files: $e');
      return [];
    }
  }

  /// Delete a PDF file
  Future<bool> deletePdfFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting PDF file: $e');
      return false;
    }
  }

  /// Get file size in MB
  Future<double> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.length();
        return bytes / (1024 * 1024); // Convert to MB
      }
      return 0.0;
    } catch (e) {
      print('Error getting file size: $e');
      return 0.0;
    }
  }

  /// Get file name from path
  String getFileName(String filePath) {
    return filePath.split('/').last;
  }

  /// Check if file exists
  Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get the documents directory path
  Future<String> getDocumentsPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$_documentsFolder';
  }
}
