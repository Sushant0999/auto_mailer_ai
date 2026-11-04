import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:auto_mail_ai/services/resume_editor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Resume section parsing correctly identifies headers and content', () {
    final editor = ResumeEditorService();
    const resumeSample = '''
Alex Mercer
alex@example.com | 555-0199

Summary:
Full-stack software engineer with 5 years of experience in distributed cloud architectures.

Technical Skills:
Flutter, Dart, Python, Docker, PostgreSQL

Work Experience:
Senior Developer at TechCorp
- Developed automated pipeline reducing job application latency by 45%.
- Implemented robust error handling and database persistence.
''';

    final sections = editor.parseResumeSections(resumeSample);
    expect(sections.isNotEmpty, true);
    final sectionNames = sections.map((s) => s['section']?.toLowerCase()).toList();
    expect(sectionNames.any((name) => name!.contains('summary')), true);
    expect(sectionNames.any((name) => name!.contains('skills')), true);
  });

  test('In-place PDF replacement maintains PDF validity and applies updates', () async {
    // 1. Generate a test PDF with known structure
    final document = PdfDocument();
    final page = document.pages.add();
    final font = PdfStandardFont(PdfFontFamily.helvetica, 12);

    page.graphics.drawString(
      'Senior Flutter Engineer',
      font,
      bounds: const Rect.fromLTWH(50, 60, 400, 20),
    );
    page.graphics.drawString(
      'Skills: Java, Spring Boot, MySQL',
      font,
      bounds: const Rect.fromLTWH(50, 100, 400, 20),
    );

    final tempDir = await Directory.systemTemp.createTemp('resume_test_');
    final samplePdfFile = File('${tempDir.path}/original_resume.pdf');
    await samplePdfFile.writeAsBytes(document.saveSync());
    document.dispose();

    // 2. Perform in-place update using ResumeEditorService
    final editor = ResumeEditorService();
    final replacements = [
      ResumeReplacement(
        section: 'Skills',
        originalText: 'Skills: Java, Spring Boot, MySQL',
        updatedText: 'Skills: Flutter, Dart, Groq AI, Cloud Architecture',
      ),
    ];

    final updatedPath = await editor.updateResumeInPlace(
      originalFilePath: samplePdfFile.path,
      replacements: replacements,
      setAsActiveResume: false,
      customOutputDirectory: tempDir,
    );

    // 3. Verify updated file exists and text is present
    final updatedFile = File(updatedPath);
    expect(await updatedFile.exists(), true);

    final updatedDoc = PdfDocument(inputBytes: await updatedFile.readAsBytes());
    final extractor = PdfTextExtractor(updatedDoc);
    final text = extractor.extractText();
    expect(text.contains('Flutter, Dart, Groq AI'), true);
    updatedDoc.dispose();

    // Cleanup
    await tempDir.delete(recursive: true);
  });
}
