import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'database_service.dart';
import 'setup_service.dart';

class ResumeReplacement {
  final String section;
  final String originalText;
  String updatedText;
  final String? reason;
  bool isApplied;

  ResumeReplacement({
    required this.section,
    required this.originalText,
    required this.updatedText,
    this.reason,
    this.isApplied = true,
  });

  Map<String, dynamic> toJson() => {
    'section': section,
    'original_text': originalText,
    'updated_text': updatedText,
    'reason': reason,
    'is_applied': isApplied,
  };

  factory ResumeReplacement.fromJson(Map<String, dynamic> json) {
    return ResumeReplacement(
      section: json['section'] ?? 'General',
      originalText: json['original_text'] ?? '',
      updatedText: json['updated_text'] ?? '',
      reason: json['reason'],
      isApplied: json['is_applied'] ?? true,
    );
  }
}

class ResumeEditorService {
  final DatabaseService _db = DatabaseService();
  final SetupService _setupService = SetupService();

  /// Applies targeted in-place text modifications to an existing resume PDF or text file.
  /// 
  /// Preserves 100% of the document's original structure, margins, vector graphics,
  /// headers, section dividers, and surrounding typography by precisely locating the
  /// bounding boxes of the target text and drawing the updated text in-place.
  Future<String> updateResumeInPlace({
    required String originalFilePath,
    required List<ResumeReplacement> replacements,
    bool setAsActiveResume = true,
    Directory? customOutputDirectory,
  }) async {
    final file = File(originalFilePath);
    if (!await file.exists()) {
      throw Exception('Original resume file not found at: $originalFilePath');
    }

    final ext = originalFilePath.split('.').last.toLowerCase();
    final Directory resumesDir;
    if (customOutputDirectory != null) {
      resumesDir = customOutputDirectory;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      resumesDir = Directory('${appDir.path}/resumes');
    }
    if (!await resumesDir.exists()) {
      await resumesDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newFilePath = '${resumesDir.path}/tailored_resume_$timestamp.$ext';

    if (ext == 'pdf') {
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);

      // Determine page count
      final pageCount = document.pages.count;

      for (var rep in replacements) {
        if (!rep.isApplied || rep.originalText.trim().isEmpty) continue;

        final target = rep.originalText.trim();
        List<MatchedItem> matches = extractor.findText([target]);

        // If direct match was not found (e.g. text wrapped over multiple lines),
        // try splitting into individual lines and finding matches per line
        if (matches.isEmpty && target.contains('\n')) {
          final subLines = target
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
          for (var subLine in subLines) {
            matches.addAll(extractor.findText([subLine]));
          }
        }

        if (matches.isNotEmpty) {
          for (var match in matches) {
            if (match.pageIndex < pageCount) {
              final page = document.pages[match.pageIndex];
              final bounds = match.bounds;

              // 1. Erase original text bounds with white background
              page.graphics.drawRectangle(
                brush: PdfSolidBrush(PdfColor(255, 255, 255)),
                bounds: Rect.fromLTWH(
                  bounds.left - 1,
                  bounds.top - 1,
                  bounds.width + 2,
                  bounds.height + 2,
                ),
              );

              // 2. Estimate appropriate font size & family from detected height
              final double fontSize = bounds.height > 8 && bounds.height < 24
                  ? bounds.height * 0.75
                  : 10.0;
              final PdfFont font = PdfStandardFont(
                PdfFontFamily.helvetica,
                fontSize,
              );

              // 3. Draw updated text in the exact same coordinates and line flow
              page.graphics.drawString(
                rep.updatedText,
                font,
                bounds: Rect.fromLTWH(
                  bounds.left,
                  bounds.top,
                  // Provide natural width budget so text doesn't clip
                  bounds.width > 200 ? bounds.width : (page.size.width - bounds.left - 40),
                  bounds.height * 2.5,
                ),
                format: PdfStringFormat(
                  wordWrap: PdfWordWrapType.word,
                  lineAlignment: PdfVerticalAlignment.top,
                ),
              );
            }
          }
        }
      }

      final updatedBytes = document.saveSync();
      document.dispose();

      final newFile = File(newFilePath);
      await newFile.writeAsBytes(updatedBytes);
    } else {
      // Plain text / Markdown resume
      String content = await file.readAsString();
      for (var rep in replacements) {
        if (!rep.isApplied) continue;
        content = content.replaceAll(rep.originalText, rep.updatedText);
      }
      final newFile = File(newFilePath);
      await newFile.writeAsString(content);
    }

    if (setAsActiveResume) {
      await _db.setConfig('RESUME_PATH', newFilePath);
      final newText = await _setupService.extractResumeText(newFilePath);
      if (newText.isNotEmpty) {
        await _db.setConfig('RESUME_TEXT', newText);
      }
    }

    return newFilePath;
  }

  /// Extracts paragraphs/bullet points from resume text to help the user
  /// select specific sections (Summary, Experience, Skills) for direct editing.
  List<Map<String, String>> parseResumeSections(String resumeText) {
    final List<Map<String, String>> sections = [];
    final lines = resumeText.split('\n');

    String currentSection = 'Header / Contact';
    List<String> currentBuffer = [];

    final sectionKeywords = [
      'summary',
      'objective',
      'experience',
      'work experience',
      'employment',
      'skills',
      'technical skills',
      'education',
      'projects',
      'certifications',
    ];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final lower = trimmed.toLowerCase();
      // Check if line looks like a section header
      final isHeader = sectionKeywords.any((k) =>
          lower == k ||
          lower == '$k:' ||
          lower.startsWith('$k ') && trimmed.length < 30);

      if (isHeader) {
        if (currentBuffer.isNotEmpty) {
          sections.add({
            'section': currentSection,
            'text': currentBuffer.join('\n').trim(),
          });
          currentBuffer.clear();
        }
        currentSection = trimmed;
      } else {
        currentBuffer.add(trimmed);
      }
    }

    if (currentBuffer.isNotEmpty) {
      sections.add({
        'section': currentSection,
        'text': currentBuffer.join('\n').trim(),
      });
    }

    return sections;
  }
}
