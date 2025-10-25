import 'dart:io';
import 'dart:typed_data';
import 'package:agconnect_cloudstorage/agconnect_cloudstorage.dart';

class CloudStorageService {
  static final CloudStorageService _instance = CloudStorageService._internal();
  factory CloudStorageService() => _instance;
  CloudStorageService._internal();

  AGCStorageReference? _storageReference;
  static bool _isInitialized = false; // Changed to static

  // Supported media types
  static const List<String> supportedImageFormats = [
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif'
  ];
  static const List<String> supportedVideoFormats = [
    'mp4', 'mov', 'avi', 'mkv', 'flv', 'wmv', '3gp', 'webm'
  ];
  static const List<String> supportedAudioFormats = [
    'mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac', 'wma'
  ];

  /// Initialize Cloud Storage - call this in main.dart
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('[CloudStorage] Initializing Cloud Storage...');
      
      // Get AGCStorage instance
      final storage = AGCStorage.getInstance();
      
      final bucketName = 'media-hbvbj'; // From your agconnect-services.json
      final bucketUrl = 'agc://$bucketName';
      
      print('[CloudStorage] Attempting to connect to bucket: $bucketName');
      print('[CloudStorage] Bucket URL: $bucketUrl');
      print('[CloudStorage] SDK will auto-route to SG region');

      final reference = await storage.referenceFromUrl(bucketUrl);
      _instance._storageReference = reference;
      
      final bucket = reference.bucket;
      print('[CloudStorage] ✅ Connected to bucket: $bucket');
      print('[CloudStorage] Region routing: Singapore (ops-dra.agcstorage.link)');
      
      _isInitialized = true;
      print('[CloudStorage] ✅ Initialization complete');
      return;
    } catch (e, stackTrace) {
      print('[CloudStorage] ❌ Initialization failed: $e');
      print('[CloudStorage] Stack trace: $stackTrace');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Upload a file to Cloud Storage
  /// 
  /// [localFilePath] - Local file path (e.g., from image picker)
  /// [cloudPath] - Destination path in cloud (e.g., 'incidents/123/media.jpg')
  /// 
  /// Returns true if upload succeeds
  Future<bool> uploadFile(
    String localFilePath, 
    String cloudPath,
  ) async {
    print('[CloudStorage] uploadFile called - isInitialized: $_isInitialized');
    
    if (!_isInitialized) {
      print('[CloudStorage] ❌ Not initialized. Call initialize() first.');
      print('[CloudStorage] Attempting to re-initialize...');
      try {
        await initialize();
        if (!_isInitialized) {
          print('[CloudStorage] ❌ Re-initialization failed');
          return false;
        }
        print('[CloudStorage] ✅ Re-initialization successful');
      } catch (e) {
        print('[CloudStorage] ❌ Re-initialization error: $e');
        return false;
      }
    }

    try {
      print('[CloudStorage] Starting upload...');
      print('[CloudStorage] Local path: $localFilePath');
      print('[CloudStorage] Cloud path: $cloudPath');

      final file = File(localFilePath);
      
      // Check if file exists
      if (!await file.exists()) {
        print('[CloudStorage] ❌ File does not exist: $localFilePath');
        return false;
      }

      // Get file size
      final fileSize = await file.length();
      print('[CloudStorage] File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Double-check _storageReference is not null
      if (_storageReference == null) {
        print('[CloudStorage] ❌ Storage reference is null!');
        return false;
      }

      // Get file reference
      final fileReference = _storageReference!.child(cloudPath);
      print('[CloudStorage] Got file reference for: $cloudPath');

      // Upload file
      await fileReference.uploadFile(File(localFilePath));

      print('[CloudStorage] ✅ Upload successful: $cloudPath');
      return true;
    } catch (e, stackTrace) {
      print('[CloudStorage] ❌ Upload failed: $e');
      print('[CloudStorage] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Upload an image file
  Future<bool> uploadImage(
    String localFilePath,
    String cloudPath,
  ) async {
    print('[CloudStorage] uploadImage called');
    if (!_isValidMediaType(localFilePath, supportedImageFormats)) {
      print('[CloudStorage] ❌ Invalid image format');
      return false;
    }
    return uploadFile(localFilePath, cloudPath);
  }

  /// Upload a video file
  Future<bool> uploadVideo(
    String localFilePath,
    String cloudPath,
  ) async {
    if (!_isValidMediaType(localFilePath, supportedVideoFormats)) {
      print('[CloudStorage] ❌ Invalid video format');
      return false;
    }
    return uploadFile(localFilePath, cloudPath);
  }

  /// Upload an audio file
  Future<bool> uploadAudio(
    String localFilePath,
    String cloudPath,
  ) async {
    if (!_isValidMediaType(localFilePath, supportedAudioFormats)) {
      print('[CloudStorage] ❌ Invalid audio format');
      return false;
    }
    return uploadFile(localFilePath, cloudPath);
  }

  /// Validate media file type
  bool _isValidMediaType(String filePath, List<String> supportedFormats) {
    final extension = _getFileExtension(filePath);
    return supportedFormats.contains(extension);
  }

  /// Get media type from file path
  String getMediaType(String filePath) {
    final extension = _getFileExtension(filePath);
    
    if (supportedImageFormats.contains(extension)) {
      return 'image';
    } else if (supportedVideoFormats.contains(extension)) {
      return 'video';
    } else if (supportedAudioFormats.contains(extension)) {
      return 'audio';
    }
    
    return 'unknown';
  }

  /// Get file extension from path
  String getFileExtension(String filePath) {
    return _getFileExtension(filePath);
  }

  /// Helper method to extract file extension
  String _getFileExtension(String filePath) {
    if (filePath.contains('.')) {
      return filePath.split('.').last.toLowerCase();
    }
    return '';
  }

  /// Get download URL for a file in Cloud Storage
  /// 
  /// [cloudPath] - Path to file in cloud storage
  /// 
  /// Returns download URL string or null if failed
  Future<String?> getDownloadUrl(String cloudPath) async {
    if (!_isInitialized) {
      print('[CloudStorage] ❌ Not initialized for getDownloadUrl');
      return null;
    }

    try {
      print('[CloudStorage] Getting download URL for: $cloudPath');

      final fileReference = _storageReference!.child(cloudPath);
      final downloadUrl = await fileReference.getDownloadUrl();

      print('[CloudStorage] ✅ Download URL obtained');
      return downloadUrl;
    } catch (e) {
      print('[CloudStorage] ❌ Failed to get download URL: $e');
      return null;
    }
  }

  /// Delete a file from Cloud Storage
  Future<bool> deleteFile(String cloudPath) async {
    if (!_isInitialized) {
      print('[CloudStorage] ❌ Not initialized for deleteFile');
      return false;
    }

    try {
      print('[CloudStorage] Deleting file: $cloudPath');
      final fileReference = _storageReference!.child(cloudPath);
      await fileReference.deleteFile();
      print('[CloudStorage] ✅ File deleted successfully');
      return true;
    } catch (e) {
      print('[CloudStorage] ❌ Delete failed: $e');
      return false;
    }
  }

  /// Get file metadata
  Future<AGCStorageMetadata?> getFileMetadata(String cloudPath) async {
    if (!_isInitialized) {
      print('[CloudStorage] ❌ Not initialized for getFileMetadata');
      return null;
    }

    try {
      print('[CloudStorage] Getting metadata for: $cloudPath');
      final fileReference = _storageReference!.child(cloudPath);
      final metadata = await fileReference.getMetadata();
      print('[CloudStorage] ✅ Metadata retrieved');
      return metadata;
    } catch (e) {
      print('[CloudStorage] ❌ Failed to get metadata: $e');
      return null;
    }
  }

  /// List all files in a directory
  Future<AGCStorageListResult?> listFiles(
    String cloudPath, {
    int maxResults = 100,
  }) async {
    if (!_isInitialized) {
      print('[CloudStorage] ❌ Not initialized for listFiles');
      return null;
    }

    try {
      print('[CloudStorage] Listing files in: $cloudPath');
      final dirReference = _storageReference!.child(cloudPath);
      final listResult = await dirReference.list(maxResults);
      print('[CloudStorage] ✅ Found ${listResult.fileList.length} files');
      return listResult;
    } catch (e) {
      print('[CloudStorage] ❌ Failed to list files: $e');
      return null;
    }
  }

  /// Download a file from Cloud Storage to local device
  Future<bool> downloadFile(String cloudPath, String localDestinationPath) async {
    if (!_isInitialized) {
      print('[CloudStorage] ❌ Not initialized for downloadFile');
      return false;
    }

    try {
      print('[CloudStorage] Downloading file...');
      print('[CloudStorage] Cloud path: $cloudPath');
      print('[CloudStorage] Local destination: $localDestinationPath');

      final fileReference = _storageReference!.child(cloudPath);
      await fileReference.downloadToFile(File(localDestinationPath));

      print('[CloudStorage] ✅ Download successful');
      return true;
    } catch (e) {
      print('[CloudStorage] ❌ Download failed: $e');
      return false;
    }
  }

  /// Upload data from bytes
  Future<bool> uploadBytes(Uint8List bytes, String cloudPath) async {
    if (!_isInitialized) {
      print('[CloudStorage] ❌ Not initialized for uploadBytes');
      return false;
    }

    try {
      print('[CloudStorage] Uploading bytes...');
      print('[CloudStorage] Cloud path: $cloudPath');
      print('[CloudStorage] Size: ${(bytes.length / 1024).toStringAsFixed(2)} KB');

      final fileReference = _storageReference!.child(cloudPath);
      await fileReference.uploadData(bytes);

      print('[CloudStorage] ✅ Bytes uploaded successfully');
      return true;
    } catch (e) {
      print('[CloudStorage] ❌ Bytes upload failed: $e');
      return false;
    }
  }

  /// Download file as bytes
  Future<Uint8List?> downloadBytes(String cloudPath, {int maxSize = 10485760}) async {
    if (!_isInitialized) {
      print('[CloudStorage] ❌ Not initialized for downloadBytes');
      return null;
    }

    try {
      print('[CloudStorage] Downloading bytes...');
      print('[CloudStorage] Cloud path: $cloudPath');

      final fileReference = _storageReference!.child(cloudPath);
      final bytes = await fileReference.downloadData(maxSize);

      print('[CloudStorage] ✅ Download successful');
      return bytes;
    } catch (e) {
      print('[CloudStorage] ❌ Download failed: $e');
      return null;
    }
  }
}