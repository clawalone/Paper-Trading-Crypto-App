import 'package:stock_arena/core/app_material.dart';

/// Centralized avatar manager that provides locally bundled assets for all user avatars,
/// eliminating redundant network downloads and saving cellular/WiFi data across screens.
class AppAvatarHelper {
  AppAvatarHelper._();

  static const String defaultFallback = 'assets/avatars/unicorn.webp';

  static const List<String> localAvatars = [
    'assets/avatars/cat.webp',
    'assets/avatars/dog.webp',
    'assets/avatars/fox.webp',
    'assets/avatars/bear.webp',
    'assets/avatars/panda.webp',
    'assets/avatars/rabbit.webp',
    'assets/avatars/tiger.webp',
    'assets/avatars/lion.webp',
    'assets/avatars/monkey.webp',
    'assets/avatars/unicorn.webp',
  ];

  /// Resolves any avatar string (URL, file name, or local asset path) to a bundled local asset.
  static String? getLocalAsset(String? input, {bool animated = true}) {
    if (input == null || input.trim().isEmpty) return null;
    final lower = input.trim().toLowerCase();

    // Match by animal name / filename
    for (final animal in [
      'cat',
      'dog',
      'fox',
      'bear',
      'panda',
      'rabbit',
      'tiger',
      'lion',
      'monkey',
      'unicorn'
    ]) {
      if (lower.contains(animal)) {
        return 'assets/avatars/$animal.webp';
      }
    }

    // Already a local asset path
    if (lower.startsWith('assets/avatars/')) {
      return input.trim();
    }

    return null;
  }

  /// Returns a Flutter ImageProvider for the given avatar.
  /// Automatically prefers local bundled asset over network downloading.
  static ImageProvider getImageProvider(String? avatarUrl, {String? fallbackAsset, bool animated = true}) {
    final local = getLocalAsset(avatarUrl, animated: animated);
    if (local != null) {
      return AssetImage(local);
    }
    if (avatarUrl != null && (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))) {
      return NetworkImage(avatarUrl);
    }
    return AssetImage(fallbackAsset ?? defaultFallback);
  }
}

/// High-performance Avatar widget that uses locally bundled assets by default
/// with zero network overhead, zero latency, and instant offline rendering.
class AppAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double size;
  final double? radius;
  final String? fallbackName;
  final Color? backgroundColor;
  final Border? border;
  final ShapeBorder shape;
  final bool animate;

  const AppAvatar({
    super.key,
    required this.avatarUrl,
    this.size = 36,
    this.radius,
    this.fallbackName,
    this.backgroundColor,
    this.border,
    this.shape = const CircleBorder(),
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSize = radius != null ? radius! * 2 : size;
    final localAsset = AppAvatarHelper.getLocalAsset(avatarUrl, animated: animate);

    Widget imageContent;
    if (localAsset != null) {
      // 100% offline, zero network data consumed, smooth GPU animated playback
      imageContent = Image.asset(
        localAsset,
        width: effectiveSize,
        height: effectiveSize,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildFallback(context, effectiveSize),
      );
    } else if (avatarUrl != null &&
        (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://'))) {
      // Custom external URL
      imageContent = Image.network(
        avatarUrl!,
        width: effectiveSize,
        height: effectiveSize,
        fit: BoxFit.cover,
        cacheWidth: (effectiveSize * 2.5).toInt(),
        cacheHeight: (effectiveSize * 2.5).toInt(),
        errorBuilder: (_, __, ___) => _buildFallback(context, effectiveSize),
      );
    } else {
      imageContent = _buildFallback(context, effectiveSize);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBgColor = isDark ? const Color(0xFF2B3139) : const Color(0xFFEEF2F6);

    Widget avatar = ClipOval(
      child: Container(
        width: effectiveSize,
        height: effectiveSize,
        color: backgroundColor ?? defaultBgColor,
        alignment: Alignment.center,
        child: imageContent,
      ),
    );

    if (border != null) {
      avatar = Container(
        width: effectiveSize,
        height: effectiveSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: border,
        ),
        child: avatar,
      );
    }

    return Center(
      child: SizedBox(
        width: effectiveSize,
        height: effectiveSize,
        child: avatar,
      ),
    );
  }

  Widget _buildFallback(BuildContext context, double size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final letter = (fallbackName != null && fallbackName!.trim().isNotEmpty)
        ? fallbackName!.trim()[0].toUpperCase()
        : 'T';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
