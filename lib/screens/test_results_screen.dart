import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/prescription_models.dart';
import '../services/auth_service.dart';
import '../services/prescription_store.dart';
import '../utils/formatters.dart';
import '../utils/app_colors.dart';
import '../widgets/open_file_helper.dart';

class TestResultsScreen extends StatefulWidget {
  final String patientId;
  final bool isDoctor;

  const TestResultsScreen({
    super.key,
    required this.patientId,
    this.isDoctor = false,
  });

  @override
  State<TestResultsScreen> createState() => _TestResultsScreenState();
}

class _TestResultsScreenState extends State<TestResultsScreen> {
  String get _viewerId => authService.currentUser?.id ?? '';

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _uploadResult(RecommendedTest test) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
      );

      // The person closed the picker without choosing a file.
      if (!mounted || result == null) return;

      final file = result.files.single;
      final path = file.path;
      if (path == null) {
        _showError(
          'This file is not stored on your phone. Save it to your phone first, then choose it again.',
        );
        return;
      }

      prescriptionStore.uploadTestResult(
        patientId: widget.patientId,
        testId: test.id,
        fileName: file.name,
        filePath: path,
      );
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test result uploaded successfully.')),
      );
    } on PlatformException catch (e) {
      debugPrint('File picker problem: $e');
      if (!mounted) return;
      _showError(
        'The file picker could not open. Check that Healthbook is allowed to use files on this phone, then try again.',
      );
    } on PrescriptionException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      debugPrint('Upload failed: $e');
      if (!mounted) return;
      _showError('Something went wrong while uploading the file. Please try again.');
    }
  }

  void _viewResult(RecommendedTest test) {
    openUploadedFile(
      context,
      title: test.uploadedFileName ?? test.name,
      path: test.uploadedFilePath ?? '',
      subtitle: test.uploadedAt != null
          ? '${test.name} • uploaded ${formatDateTime(test.uploadedAt!)}'
          : test.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewerId = _viewerId;
    final canView = prescriptionStore.canView(widget.patientId, viewerId);
    final isPatient = viewerId == widget.patientId;
    final tests = prescriptionStore.recommendedTestsFor(widget.patientId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Test Results & Recommendations'),
      ),
      body: !canView
          ? const Center(child: Text('You do not have access to these test results.'))
          : tests.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      isPatient
                          ? 'No medical tests recommended yet. Tests your doctor recommends will appear here.'
                          : 'No medical tests recommended for this patient.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: tests.length,
                  itemBuilder: (context, index) {
                    final test = tests[index];
                    final isUploaded = test.status == 'Result Uploaded';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  test.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF0D1B2A),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isUploaded ? Colors.green.shade50 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isUploaded ? Colors.green.shade200 : Colors.orange.shade200,
                                  ),
                                ),
                                child: Text(
                                  test.status,
                                  style: TextStyle(
                                    color: isUploaded ? kTextSuccess : kTextWarning,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Recommended by ${test.recommendingDoctorName.isEmpty ? 'Doctor' : test.recommendingDoctorName} • ${formatDateTime(test.recommendedAt)}',
                            style: TextStyle(color: Colors.grey[700], fontSize: 14),
                          ),
                          if (test.instructions.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Instructions: ${test.instructions}', style: const TextStyle(color: kTextMuted, fontSize: 14)),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (isUploaded)
                                TextButton.icon(
                                  onPressed: () => _viewResult(test),
                                  icon: const Icon(Icons.visibility_outlined, size: 18),
                                  label: Text(test.uploadedFileName ?? 'View Result'),
                                )
                              else
                                const Text('No result uploaded yet', style: TextStyle(color: kTextMuted, fontSize: 14)),
                              if (isPatient)
                                ElevatedButton.icon(
                                  onPressed: () => _uploadResult(test),
                                  icon: const Icon(Icons.upload_file, size: 18),
                                  label: Text(isUploaded ? 'Replace Result' : 'Upload Result'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF102A66),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
