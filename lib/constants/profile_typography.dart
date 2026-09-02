import 'package:sizer/sizer.dart';

/// Readable font sizes for profile cards. Uses sizer with a minimum floor so
/// subtitles stay legible on web and large screens.
class ProfileTypography {
  ProfileTypography._();

  static double _sp(double size, {double min = 12}) {
    final scaled = size.sp;
    return scaled < min ? min : scaled;
  }

  /// Card section title — e.g. "Settings", "Emergency Contact"
  static double get sectionTitle => _sp(16, min: 16);

  /// Primary row label — e.g. "Language", "Push Notifications"
  static double get rowLabel => _sp(14, min: 14);

  /// Secondary subtitle — e.g. "English", notification description
  static double get subtitle => _sp(13, min: 13);

  /// Toggle / list option label — e.g. "Public Profile"
  static double get optionLabel => _sp(13, min: 13);

  /// Action link — e.g. "Modify"
  static double get action => _sp(13, min: 13);

  /// Badge / meta — e.g. "EN", phone number
  static double get caption => _sp(12, min: 12);

  /// Contact name / emphasized inline text
  static double get emphasis => _sp(14, min: 14);
}
