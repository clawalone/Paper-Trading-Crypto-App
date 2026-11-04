import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/icon.png').readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Failed to decode image');
    return;
  }
  
  // Crop center 70% to zoom in on the logo elements
  int newWidth = (image.width * 0.70).toInt();
  int newHeight = (image.height * 0.70).toInt();
  int x = (image.width - newWidth) ~/ 2;
  int y = (image.height - newHeight) ~/ 2;
  
  final cropped = img.copyCrop(image, x: x, y: y, width: newWidth, height: newHeight);
  
  // Resize back up to 1024x1024 for high quality
  final resized = img.copyResize(cropped, width: 1024, height: 1024, interpolation: img.Interpolation.linear);
  
  File('assets/icon.png').writeAsBytesSync(img.encodePng(resized));
  print('done');
}
