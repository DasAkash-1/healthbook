import 'package:flutter_test/flutter_test.dart';

import 'package:healthbook_test/utils/allergy_check.dart';

void main() {
  group('matchingAllergies', () {
    test('finds a medicine that is listed as an allergy', () {
      expect(matchingAllergies('Penicillin V', 'Penicillin'), ['Penicillin']);
      expect(matchingAllergies('aspirin 75 mg', 'Aspirin'), ['Aspirin']);
    });

    test('ignores notes in brackets and picks the right entry from a list', () {
      expect(
        matchingAllergies('Penicillin 250 mg', 'Penicillin (rash), Peanuts'),
        ['Penicillin (rash)'],
      );
    });

    test('works when the allergy is written as a sentence', () {
      expect(
        matchingAllergies('Penicillin V', 'Allergic to penicillin'),
        ['Allergic to penicillin'],
      );
      expect(
        matchingAllergies('Penicillin V', 'Sulfa drugs and penicillin'),
        ['penicillin'],
      );
    });

    test('matches the start of a longer medicine name', () {
      expect(
        matchingAllergies('Sulfamethoxazole', 'Sulfa drugs'),
        ['Sulfa drugs'],
      );
    });

    test('finds short 3-letter allergens like ASA, Egg, or Soy', () {
      expect(matchingAllergies('ASA 75 mg', 'ASA (Aspirin)'), ['ASA (Aspirin)']);
      expect(matchingAllergies('Egg lecithin capsule', 'Egg'), ['Egg']);
    });

    test('finds nothing when the allergy is unrelated', () {
      expect(matchingAllergies('Metformin 500 mg', 'Peanuts, Latex'), isEmpty);
    });

    test('"None" and similar entries never match', () {
      expect(matchingAllergies('Metformin', 'None'), isEmpty);
      expect(matchingAllergies('None', 'None'), isEmpty);
      expect(matchingAllergies('Metformin', 'No known allergies'), isEmpty);
    });

    test('very short names do not cause false matches', () {
      expect(matchingAllergies('Ac', 'Peanuts'), isEmpty);
      expect(matchingAllergies('', 'Penicillin'), isEmpty);
    });
  });

  group('allergyWarningsFor', () {
    test('only lists the medicines that match', () {
      final warnings = allergyWarningsFor(
        ['Metformin', ' Penicillin V '],
        'Penicillin',
      );
      expect(warnings, hasLength(1));
      expect(warnings.first.medicine, 'Penicillin V');
      expect(warnings.first.allergies, ['Penicillin']);
    });
  });
}
