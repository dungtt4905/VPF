import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageStorageService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  Future<(String localImagePath, String localThumbnailPath)?> pickAndProcessImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return null;
    return processImageFile(pickedFile.path);
  }

  /// Nén ảnh đại diện (tối đa ~512px) và lưu vào thư mục của app. Trả về đường dẫn file, hoặc null nếu lỗi.
  Future<String?> processAvatar(String filePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final outPath = '${dir.path}/avatar_${_uuid.v4()}.jpg';
    final file = await FlutterImageCompress.compressAndGetFile(
      filePath,
      outPath,
      quality: 85,
      minWidth: 512,
      minHeight: 512,
      format: CompressFormat.jpeg,
    );
    return file?.path;
  }

  Future<(String localImagePath, String localThumbnailPath)?> processImageFile(String filePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final id = _uuid.v4();
    
    final fullPath = '${dir.path}/${id}_full.jpg';
    final thumbPath = '${dir.path}/${id}_thumb.jpg';

    // Compress Full Size (max width ~1080px)
    final fullSizeFile = await FlutterImageCompress.compressAndGetFile(
      filePath,
      fullPath,
      quality: 80,
      minWidth: 1080,
      format: CompressFormat.jpeg,
    );

    // Compress Thumbnail (max width ~300px)
    final thumbFile = await FlutterImageCompress.compressAndGetFile(
      filePath,
      thumbPath,
      quality: 70,
      minWidth: 300,
      format: CompressFormat.jpeg,
    );

    if (fullSizeFile != null && thumbFile != null) {
      return (fullSizeFile.path, thumbFile.path);
    }
    
    return null;
  }
}
