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

  /// Validates vital signs
  static String? heartRate(String? value) {
    return numericRange(value, 30, 250, 'Heart rate');
  }

  static String? bloodPressureSystolic(String? value) {
    return numericRange(value, 70, 250, 'Systolic BP');
  }

  static String? bloodPressureDiastolic(String? value) {
    return numericRange(value, 40, 150, 'Diastolic BP');
  }

  static String? oxygenSaturation(String? value) {
    return numericRange(value, 0, 100, 'Oxygen saturation');
  }

  static String? temperature(String? value) {
    return numericRange(value, 35, 43, 'Temperature');
  }

  static String? respiratoryRate(String? value) {
    return numericRange(value, 5, 60, 'Respiratory rate');
  }

  static String? glucoseLevel(String? value) {
    final error = numeric(value, 'Glucose level');
    if (error != null) return error;
    
    final number = double.parse(value!);
    if (number < 0 || number > 1000) {
      return 'Glucose level seems invalid';
    }
    return null;
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
