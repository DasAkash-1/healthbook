import '../models/medical_history.dart';
import 'prescription_store.dart';

class MedicalHistoryException implements Exception {
  final String message;
  MedicalHistoryException(this.message);

  @override
  String toString() => message;
}

// In-memory medical history. Replace with a Firebase version later, keeping the same methods.
//
// TODO(backend): read and write the history in the database. Keep the method names and
// the MedicalHistoryException messages the same. The access rules below must also be
// enforced on the server, not only here.
//
// Rules:
// - The patient can view and update their own history.
// - A doctor can only view it, and only with the patient's access (same grant as prescriptions).
// - Nobody but the patient can change it.
class MedicalHistoryStore {
  final PrescriptionStore _access;
  final Map<String, MedicalHistory> _records = {};

  MedicalHistoryStore(this._access);

  // Returns null if the patient hasn't recorded anything yet.
  // TODO(backend): read the history from the database.
  MedicalHistory? historyFor(String patientId, String viewerId) {
    if (!_access.canView(patientId, viewerId)) {
      throw MedicalHistoryException('You do not have access to this medical history.');
    }
    return _records[patientId];
  }

  // TODO(backend): save the history in the database.
  void save({
    required String patientId,
    required String editorId,
    required MedicalHistory history,
  }) {
    if (editorId != patientId) {
      throw MedicalHistoryException('Only the patient can update their medical history.');
    }
    if (history.allergies.trim().isEmpty) {
      throw MedicalHistoryException('Allergies are required. Write "None" if you have none.');
    }
    _records[patientId] = history;
  }
}

// The app-wide medical history store.
final MedicalHistoryStore medicalHistoryStore = MedicalHistoryStore(prescriptionStore);
