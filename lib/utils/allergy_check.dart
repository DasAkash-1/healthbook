// A medicine that looks like something on the patient's allergy list.
class AllergyWarning {
  final String medicine;
  final List<String> allergies; // the entries from the allergy list that matched

  const AllergyWarning(this.medicine, this.allergies);
}

// Words that carry no information when comparing ("allergic to penicillin").
const Set<String> _ignoredWords = {
  'none',
  'allergic',
  'allergy',
  'allergies',
  'reaction',
  'reactions',
  'drug',
  'drugs',
  'medicine',
  'medicines',
  'tablet',
  'tablets',
  'known',
  'severe',
  'mild',
};

// Lower-case words of 4 or more letters, so "500", "mg" and "to" are skipped.
List<String> _words(String text) {
  return RegExp(r'[a-z]{4,}')
      .allMatches(text)
      .map((m) => m.group(0)!)
      .where((w) => !_ignoredWords.contains(w))
      .toList();
}

// Which entries in the patient's allergy text look like this medicine?
//
// This is a plain text match. It finds "Penicillin" when the doctor types
// "Penicillin V", but it cannot know that two different names belong to the same
// family of medicines. It is a prompt for the doctor, not a safety guarantee.
List<String> matchingAllergies(String medicineName, String allergies) {
  final medicine = medicineName.trim().toLowerCase();
  if (medicine.isEmpty) return [];
  final medicineWords = _words(medicine);

  final matches = <String>[];
  for (final raw in allergies.split(RegExp(r'[,;\n/]|\band\b', caseSensitive: false))) {
    final entry = raw.trim();
    // Ignore notes in brackets, like "Penicillin (rash)", when comparing.
    final cleaned = entry.toLowerCase().replaceAll(RegExp(r'\(.*?\)'), '').trim();
    final entryWords = _words(cleaned);
    if (entryWords.isEmpty) continue;

    final hit = entryWords.any((w) => medicine.contains(w)) ||
        medicineWords.any((w) => cleaned.contains(w));
    if (hit && !matches.contains(entry)) matches.add(entry);
  }
  return matches;
}

// Checks every medicine name against the allergy text. Medicines with no match are left out.
List<AllergyWarning> allergyWarningsFor(
  Iterable<String> medicineNames,
  String allergies,
) {
  final warnings = <AllergyWarning>[];
  for (final name in medicineNames) {
    final found = matchingAllergies(name, allergies);
    if (found.isNotEmpty) warnings.add(AllergyWarning(name.trim(), found));
  }
  return warnings;
}
