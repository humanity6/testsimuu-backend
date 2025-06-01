import 'dart:io';
import 'package:flutter/material.dart';

class ImageUtils {
  /// Determines the appropriate ImageProvider based on the image path
  static ImageProvider getImageProvider(String imagePath) {
    if (_isValidNetworkUrl(imagePath)) {
      return NetworkImage(imagePath);
    } else if (imagePath.startsWith('assets/')) {
      return AssetImage(imagePath);
    } else if (File(imagePath).existsSync()) {
      return FileImage(File(imagePath));
    } else {
      // Default fallback
      return const AssetImage('assets/images/avatar_placeholder.png');
    }
  }
  
  /// Check if URL is a valid network URL and not a placeholder
  static bool _isValidNetworkUrl(String imagePath) {
    if (imagePath.isEmpty) return false;
    if (imagePath.contains('example.com')) return false; // Filter out example URLs
    
    try {
      final uri = Uri.parse(imagePath);
      return uri.hasScheme && 
             (uri.scheme == 'http' || uri.scheme == 'https') &&
             uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Safely loads an image with a fallback
  static Widget loadImage({
    required String imagePath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    try {
      if (imagePath.isEmpty || !_isValidNetworkUrl(imagePath)) {
        return placeholder ?? _buildDefaultPlaceholder(width, height);
      }
      
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          
          return SizedBox(
            width: width,
            height: height,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? placeholder ?? _buildDefaultPlaceholder(width, height);
        },
      );
    } catch (e) {
      return errorWidget ?? placeholder ?? _buildDefaultPlaceholder(width, height);
    }
  }
  
  static Widget _buildDefaultPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(Icons.person, color: Colors.grey),
    );
  }
} 