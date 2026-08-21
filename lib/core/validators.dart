/// Input validation utilities
class Validators {
  /// Validates email format
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Validates password strength
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validates required field
  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates numeric input
  static String? numeric(String? value, [String fieldName = 'This field']) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (double.tryParse(value) == null) {
      return '$fieldName must be a number';
    }
    return null;
  }

  /// Validates numeric range
  static String? numericRange(
    String? value,
    double min,
    double max, [
    String fieldName = 'Value',
  ]) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final number = double.tryParse(value);
    if (number == null) {
      return '$fieldName must be a number';
    }
    if (number < min || number > max) {
      return '$fieldName must be between $min and $max';
    }
    return null;
  }

  /// Validates vital signs.
  ///
  /// Ranges are wide enough to accept REAL pathology (hypothermia below
  /// 35°C, shock BP below 70 systolic, etc.) while still catching typos like
  /// an extra digit or a swapped field.
  static String? heartRate(String? value) {
    return numericRange(value, 20, 300, 'Heart rate');
  }

  static String? bloodPressureSystolic(String? value) {
    return numericRange(value, 40, 300, 'Systolic BP');
  }

  static String? bloodPressureDiastolic(String? value) {
    return numericRange(value, 20, 200, 'Diastolic BP');
  }

  static String? oxygenSaturation(String? value) {
    return numericRange(value, 40, 100, 'Oxygen saturation');
  }

  static String? temperature(String? value) {
    return numericRange(value, 30, 43, 'Temperature');
  }

  static String? respiratoryRate(String? value) {
    return numericRange(value, 4, 80, 'Respiratory rate');
  }

  static String? glucoseLevel(String? value) {
    return numericRange(value, 10, 1500, 'Glucose level');
  }

  /// Validates age
  static String? age(String? value) {
    return numericRange(value, 0, 150, 'Age');
  }

  /// Validates phone number (basic)
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  /// Sanitize string input (prevent XSS)
  static String sanitize(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .trim();
  }
}
