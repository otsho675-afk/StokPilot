import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uses the store's own review sheet only after enough successful work.
class ReviewPrompt {
  ReviewPrompt._();
  static final instance = ReviewPrompt._();
  bool _running = false;

  Future<void> recordSuccessfulTrade() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS) || _running) return;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final installed = DateTime.tryParse(
        prefs.getString('reviewFirstTradeAt') ?? '',
      );
      if (installed == null) {
        await prefs.setString('reviewFirstTradeAt', now.toIso8601String());
      }
      final count = (prefs.getInt('reviewTradeCount') ?? 0) + 1;
      await prefs.setInt('reviewTradeCount', count);
      final last = DateTime.tryParse(
        prefs.getString('reviewLastAskedAt') ?? '',
      );
      if (count < 5 ||
          installed == null ||
          now.difference(installed).inDays < 7 ||
          (last != null && now.difference(last).inDays < 90))
        return;
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      // Store APIs enforce their own limits. Record the attempt before showing it.
      await prefs.setString('reviewLastAskedAt', now.toIso8601String());
      await review.requestReview();
    } catch (_) {
      // A review request must never block a sale or purchase record.
    } finally {
      _running = false;
    }
  }
}
