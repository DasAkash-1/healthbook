// Stores custom daily reminder hours per medication frequency (1 to 4 times/day).
// Falls back to [kDefaultDoseHoursByFrequency] whenever a user has not customized
// a frequency or resets back to defaults.
class ReminderScheduleException implements Exception {
  final String message;
  ReminderScheduleException(this.message);

  @override
  String toString() => message;
}

class ReminderScheduleStore {
  // Maps frequency (1..4) -> sorted list of unique hours (0..23).
  final Map<int, List<int>> _customHours = {};

  // Returns the active hours for [timesPerDay] (custom if set, otherwise default).
  List<int> hoursFor(int timesPerDay) {
    _validateFrequency(timesPerDay);
    final custom = _customHours[timesPerDay];
    if (custom != null && custom.length == timesPerDay) {
      return List.unmodifiable(custom);
    }
    return List.unmodifiable(_defaultHoursFor(timesPerDay));
  }

  // Returns true if [timesPerDay] has a user-customized schedule.
  bool isCustomized(int timesPerDay) {
    _validateFrequency(timesPerDay);
    return _customHours.containsKey(timesPerDay);
  }

  // Returns a map of only the customized frequencies for passing into planReminders().
  Map<int, List<int>> get customHoursMap {
    return {
      for (final entry in _customHours.entries)
        entry.key: List<int>.from(entry.value),
    };
  }

  // Saves a custom list of hours for [timesPerDay].
  // Every hour must be 0..23, count must match [timesPerDay], and duplicates are rejected.
  void setHoursFor(int timesPerDay, List<int> hours) {
    _validateFrequency(timesPerDay);
    if (hours.length != timesPerDay) {
      throw ReminderScheduleException(
        'Choose exactly $timesPerDay time(s) for a $timesPerDay-times-a-day medicine.',
      );
    }
    for (final h in hours) {
      if (h < 0 || h > 23) {
        throw ReminderScheduleException('Hour must be between 00:00 and 23:00.');
      }
    }
    final uniqueSorted = hours.toSet().toList()..sort();
    if (uniqueSorted.length != timesPerDay) {
      throw ReminderScheduleException(
        'Each reminder time for the same day must be at a different hour.',
      );
    }
    _customHours[timesPerDay] = uniqueSorted;
  }

  // Clears custom hours for [timesPerDay] (or all frequencies if null).
  void resetToDefault({int? timesPerDay}) {
    if (timesPerDay == null) {
      _customHours.clear();
      return;
    }
    _validateFrequency(timesPerDay);
    _customHours.remove(timesPerDay);
  }

  void _validateFrequency(int timesPerDay) {
    if (timesPerDay < 1 || timesPerDay > 4) {
      throw ReminderScheduleException('Times per day must be between 1 and 4.');
    }
  }

  List<int> _defaultHoursFor(int timesPerDay) {
    switch (timesPerDay) {
      case 1:
        return const [9];
      case 2:
        return const [9, 21];
      case 3:
        return const [9, 14, 21];
      case 4:
        return const [9, 13, 17, 21];
      default:
        return const [9];
    }
  }
}

// App-wide singleton for custom medicine reminder hours.
final ReminderScheduleStore reminderScheduleStore = ReminderScheduleStore();
