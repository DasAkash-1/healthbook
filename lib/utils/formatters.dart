import '../models/app_models.dart';

const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String two(int n) => n.toString().padLeft(2, '0');

// e.g. "Tue 13 Oct"
String formatDay(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

// e.g. "09:00 – 09:20"
String formatSlot(DateTime start) {
  final end = start.add(kSlotLength);
  return '${two(start.hour)}:${two(start.minute)} – '
      '${two(end.hour)}:${two(end.minute)}';
}
