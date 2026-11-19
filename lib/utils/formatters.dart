import '../models/app_models.dart';

// Short weekday and month labels used to format dates and appointment slots consistently.
const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// Pads single-digit numbers with a leading zero (e.g., 9 -> "09").
String two(int n) => n.toString().padLeft(2, '0');

// Formats a date as a short day label, e.g. "Tue 13 Oct".
String formatDay(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

// Formats a 20-minute appointment window from [start], e.g. "09:00 – 09:20".
String formatSlot(DateTime start) {
  final end = start.add(kSlotLength);
  return '${two(start.hour)}:${two(start.minute)} – '
      '${two(end.hour)}:${two(end.minute)}';
}

// Formats a full day and 24-hour clock time, e.g. "Tue 13 Oct 10:30".
String formatDateTime(DateTime d) =>
    '${formatDay(d)} ${two(d.hour)}:${two(d.minute)}';
