import 'package:flutter/material.dart';

class PageTransitions {
  // Slide transition from right to left (default)
  static Route<T> slideTransition<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
    Curve curve = Curves.easeInOut,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        final offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  // Fade transition
  static Route<T> fadeTransition<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeInOut,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: curve),
        );
        final fadeAnimation = animation.drive(tween);
        
        return FadeTransition(
          opacity: fadeAnimation,
          child: child,
        );
      },
    );
  }

  // Scale transition (zoom in/out)
  static Route<T> scaleTransition<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 350),
    double begin = 0.0,
    double end = 1.0,
    Curve curve = Curves.elasticOut,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        final scaleAnimation = animation.drive(tween);
        
        return ScaleTransition(
          scale: scaleAnimation,
          child: child,
        );
      },
    );
  }

  // Slide from bottom (modal style)
  static Route<T> slideFromBottom<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: curve));
        final offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  // Rotation transition
  static Route<T> rotationTransition<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 400),
    double begin = 0.0,
    double end = 1.0,
    Curve curve = Curves.easeInOut,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        final rotationAnimation = animation.drive(tween);
        
        return RotationTransition(
          turns: rotationAnimation,
          child: child,
        );
      },
    );
  }

  // Custom combined transition (slide + fade)
  static Route<T> slideAndFadeTransition<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 350),
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
    Curve curve = Curves.easeInOut,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideTween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        final fadeTween = Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: curve),
        );
        
        final slideAnimation = animation.drive(slideTween);
        final fadeAnimation = animation.drive(fadeTween);
        
        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }

  // Hero-style transition for cards
  static Route<T> heroTransition<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 400),
    Curve curve = Curves.easeInOutCubic,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleTween = Tween(begin: 0.8, end: 1.0).chain(
          CurveTween(curve: curve),
        );
        final fadeTween = Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: curve),
        );
        
        final scaleAnimation = animation.drive(scaleTween);
        final fadeAnimation = animation.drive(fadeTween);
        
        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }
}

// Custom navigation helper methods
class NavigationHelper {
  // Navigate with slide transition
  static Future<T?> slideToPage<T extends Object?>(
    BuildContext context,
    Widget page, {
    bool replace = false,
    Offset begin = const Offset(1.0, 0.0),
  }) {
    final route = PageTransitions.slideTransition<T>(page, begin: begin);
    if (replace) {
      return Navigator.pushReplacement(context, route);
    }
    return Navigator.push(context, route);
  }

  // Navigate with fade transition
  static Future<T?> fadeToPage<T extends Object?>(
    BuildContext context,
    Widget page, {
    bool replace = false,
  }) {
    final route = PageTransitions.fadeTransition<T>(page);
    if (replace) {
      return Navigator.pushReplacement(context, route);
    }
    return Navigator.push(context, route);
  }

  // Navigate with hero transition (good for cards)
  static Future<T?> heroToPage<T extends Object?>(
    BuildContext context,
    Widget page, {
    bool replace = false,
  }) {
    final route = PageTransitions.heroTransition<T>(page);
    if (replace) {
      return Navigator.pushReplacement(context, route);
    }
    return Navigator.push(context, route);
  }

  // Navigate with slide from bottom (modal style)
  static Future<T?> modalToPage<T extends Object?>(
    BuildContext context,
    Widget page, {
    bool replace = false,
  }) {
    final route = PageTransitions.slideFromBottom<T>(page);
    if (replace) {
      return Navigator.pushReplacement(context, route);
    }
    return Navigator.push(context, route);
  }
}
