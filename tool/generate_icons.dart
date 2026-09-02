import 'dart:io';
import 'package:image/image.dart' as img;

/// Run this script to generate launcher icons from the Team Ragnarok logo.
/// Execute: dart run tool/generate_icons.dart
void main() async {
  const sourcePath =
      'assets/images/Screenshot_20250824_003459_Instagram-1785710319937.jpg';

  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    print('ERROR: Source image not found at $sourcePath');
    exit(1);
  }

  final sourceBytes = await sourceFile.readAsBytes();
  final sourceImage = img.decodeImage(sourceBytes);

  if (sourceImage == null) {
    print('ERROR: Could not decode source image');
    exit(1);
  }

  // Android mipmap sizes
  final androidSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in androidSizes.entries) {
    final dir = 'android/app/src/main/res/${entry.key}';
    await Directory(dir).create(recursive: true);

    final resized =
        img.copyResize(sourceImage, width: entry.value, height: entry.value);
    final pngBytes = img.encodePng(resized);

    await File('$dir/ic_launcher.png').writeAsBytes(pngBytes);
    await File('$dir/ic_launcher_round.png').writeAsBytes(pngBytes);
    print(
        '✓ Generated ${entry.key}/ic_launcher.png (${entry.value}x${entry.value})');
  }

  // iOS sizes
  final iosSizes = {
    'Icon-App-20x20@1x': 20,
    'Icon-App-20x20@2x': 40,
    'Icon-App-20x20@3x': 60,
    'Icon-App-29x29@1x': 29,
    'Icon-App-29x29@2x': 58,
    'Icon-App-29x29@3x': 87,
    'Icon-App-40x40@1x': 40,
    'Icon-App-40x40@2x': 80,
    'Icon-App-40x40@3x': 120,
    'Icon-App-60x60@2x': 120,
    'Icon-App-60x60@3x': 180,
    'Icon-App-76x76@1x': 76,
    'Icon-App-76x76@2x': 152,
    'Icon-App-83.5x83.5@2x': 167,
    'Icon-App-1024x1024@1x': 1024,
  };

  final iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  await Directory(iosDir).create(recursive: true);

  for (final entry in iosSizes.entries) {
    final size = entry.value;
    final resized = img.copyResize(sourceImage, width: size, height: size);
    final pngBytes = img.encodePng(resized);
    await File('$iosDir/${entry.key}.png').writeAsBytes(pngBytes);
    print('✓ Generated iOS ${entry.key}.png (${size}x${size})');
  }

  print('\n✅ All launcher icons generated successfully!');
  print('Now run: flutter build apk --release');
}
