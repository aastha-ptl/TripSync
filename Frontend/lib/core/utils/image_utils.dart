class ImageUtils {
  /// Optimizes a Cloudinary image URL by injecting transformation parameters.
  /// If the URL is not a Cloudinary URL, it returns the original URL.
  static String getOptimizedImageUrl(String? url, {int width = 400, String? fallbackName}) {
    if (url == null || url.isEmpty) {
      if (fallbackName != null && fallbackName.isNotEmpty) {
        return 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(fallbackName)}&background=E2E8F0&color=475569';
      }
      return 'https://ui-avatars.com/api/?name=%20&background=E2E8F0&color=475569';
    }
    
    // Check if it's a Cloudinary URL and doesn't already have transformations
    if (url.contains('res.cloudinary.com') && url.contains('/upload/')) {
      // If it already has transformations, just return it
      if (url.contains('/upload/w_') || url.contains('/upload/q_')) {
        return url;
      }
      
      // Inject standard optimizations: q_auto (auto quality), f_auto (auto format), w_{width}
      return url.replaceFirst('/upload/', '/upload/w_$width,q_auto,f_auto/');
    }
    
    return url;
  }
}
