extension StringExtensions on String {
  bool get isBlank => trim().isEmpty;

  String? get nullIfBlank => isBlank ? null : this;
}
