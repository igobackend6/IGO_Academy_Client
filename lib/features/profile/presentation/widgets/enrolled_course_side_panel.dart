import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../assessments/providers/assessment_provider.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';

final _courseInfoProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, courseId) async {
  final res = await Supabase.instance.client
      .from('resources')
      .select()
      .eq('course_id', courseId)
      .eq('type', 'information')
      .order('display_order');
  return (res as List).cast<Map<String, dynamic>>();
});

final _courseNotesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, courseId) async {
  final res = await Supabase.instance.client
      .from('resources')
      .select()
      .eq('course_id', courseId)
      .eq('type', 'note')
      .order('display_order');
  return (res as List).cast<Map<String, dynamic>>();
});

class EnrolledCourseSidePanel extends ConsumerWidget {
  final String courseId;
  final String courseTitle;

  const EnrolledCourseSidePanel({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppColors.background,
      width: MediaQuery.of(context).size.width * 0.88,
      child: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Course Resources',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: 'Assessment'),
                  Tab(text: 'Information'),
                  Tab(text: 'Notes'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _AssessmentTab(courseId: courseId),
                    _ResourceTab(
                        courseId: courseId,
                        providerFamily: _courseInfoProvider,
                        emptyLabel: 'information'),
                    _ResourceTab(
                        courseId: courseId,
                        providerFamily: _courseNotesProvider,
                        emptyLabel: 'notes'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Assessment Tab ───────────────────────────────────────────────────────────

class _AssessmentTab extends ConsumerWidget {
  final String courseId;
  const _AssessmentTab({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentsAsync = ref.watch(assessmentsProvider(courseId));

    return assessmentsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              const Text('Failed to load assessments',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.red)),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Colors.red, fontSize: 12),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(assessmentsProvider(courseId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (assessments) {
        if (assessments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quiz_outlined,
                      size: 56, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text('No assessments yet',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text('Course ID: $courseId',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary, fontSize: 11)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: assessments.length,
          itemBuilder: (context, i) {
            final a = assessments[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.quiz_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                '${a.questions.length} questions · Pass ${a.passScore}%'
                                '${a.timerMins != null ? ' · ⏱ ${a.timerMins} min' : ''}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/assessment-quiz', extra: a);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Start Assessment',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Resource Tab (Information / Notes) ──────────────────────────────────────

class _ResourceTab extends ConsumerStatefulWidget {
  final String courseId;
  final FutureProviderFamily<List<Map<String, dynamic>>, String> providerFamily;
  final String emptyLabel;

  const _ResourceTab({
    required this.courseId,
    required this.providerFamily,
    required this.emptyLabel,
  });

  @override
  ConsumerState<_ResourceTab> createState() => _ResourceTabState();
}

class _ResourceTabState extends ConsumerState<_ResourceTab> {
  String? _openingPdfId;

  Future<void> _openPdf(
      BuildContext ctx, String resourceId, String pdfPath, String title) async {
    setState(() => _openingPdfId = resourceId);
    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('resource-pdfs')
          .createSignedUrl(pdfPath, 3600);

      final tempDir = await getTemporaryDirectory();
      final localFile =
          File('${tempDir.path}/${pdfPath.replaceAll('/', '_')}');

      await Dio().download(signedUrl, localFile.path);

      if (!mounted) return;
      await Navigator.of(ctx).push(MaterialPageRoute(
        builder: (_) => _PdfViewerPage(filePath: localFile.path, title: title),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('Cannot open PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _openingPdfId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(widget.providerFamily(widget.courseId));

    return async.when(
      loading: () => const AppLoading(),
      error: (e, _) => AppError(message: e.toString()),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.emptyLabel == 'notes'
                        ? Icons.notes_outlined
                        : Icons.info_outline_rounded,
                    size: 56,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text('No ${widget.emptyLabel} available',
                      style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final resourceId = item['id'] as String? ?? '';
            final title = item['title'] as String? ?? '';
            final content = item['content'] as String? ?? '';
            final pdfPath = item['pdf_path'] as String?;
            final isOpeningThis = _openingPdfId == resourceId;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: pdfPath != null
                                ? Colors.red.withOpacity(0.1)
                                : AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            pdfPath != null
                                ? Icons.picture_as_pdf_outlined
                                : Icons.article_outlined,
                            color: pdfPath != null
                                ? Colors.red
                                : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ],
                    ),
                    if (content.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        content,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (pdfPath != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isOpeningThis
                              ? null
                              : () => _openPdf(
                                  context, resourceId, pdfPath, title),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: isOpeningThis
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.open_in_new, size: 16),
                          label: Text(isOpeningThis
                              ? 'Opening PDF...'
                              : 'Open PDF'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── In-app PDF viewer ────────────────────────────────────────────────────────

class _PdfViewerPage extends StatefulWidget {
  final String filePath;
  final String title;
  const _PdfViewerPage({required this.filePath, required this.title});

  @override
  State<_PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<_PdfViewerPage> {
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isReady = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        title: Text(widget.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
        actions: [
          if (_isReady)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: PDFView(
        filePath: widget.filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onRender: (pages) =>
            setState(() {
              _totalPages = pages ?? 0;
              _isReady = true;
            }),
        onPageChanged: (page, total) =>
            setState(() {
              _currentPage = page ?? 0;
              _totalPages = total ?? 0;
            }),
        onError: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF error: $e'),
                backgroundColor: Colors.red),
          );
        },
      ),
    );
  }
}
