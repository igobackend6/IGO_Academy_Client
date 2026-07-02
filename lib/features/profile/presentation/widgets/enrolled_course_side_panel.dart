import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../assessments/providers/assessment_provider.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../courses/presentation/providers/course_provider.dart';

// Real providers querying public.resources view
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                    _AssessmentTab(courseId: courseId, courseTitle: courseTitle),
                    _ResourceTab(provider: _courseInfoProvider(courseId), emptyLabel: 'information'),
                    _ResourceTab(provider: _courseNotesProvider(courseId), emptyLabel: 'notes'),
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

// ── Assessment tab — real data from public.assessments view ──────────────────

class _AssessmentTab extends ConsumerWidget {
  final String courseId;
  final String courseTitle;

  const _AssessmentTab({required this.courseId, required this.courseTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentsAsync = ref.watch(assessmentsProvider(courseId));
    final lessonsAsync = ref.watch(courseLessonsProvider(courseId));
    final completedLessonIdsAsync = ref.watch(completedLessonIdsProvider);

    return assessmentsAsync.when(
      loading: () => const AppLoading(),
      error: (e, _) => AppError(message: e.toString()),
      data: (assessments) {
        if (assessments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quiz_outlined, size: 56, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text('No assessments yet', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text('Check back after your next lesson',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }

        final lessons = lessonsAsync.value ?? [];
        final completedLessonIds = completedLessonIdsAsync.value ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: assessments.length,
          itemBuilder: (context, i) {
            final a = assessments[i];
            final subAsync = ref.watch(mySubmissionProvider(a.id));
            
            // Locked if the corresponding lesson at this index has not been completed
            bool isLocked = false;
            if (lessons.length > i) {
              final currentLesson = lessons[i];
              isLocked = !completedLessonIds.contains(currentLesson.id);
            } else {
              isLocked = i > 0;
            }

            // Build card helper — works with or without a prior submission
            Widget buildCard(Map<String, dynamic>? sub) {
              final done = sub != null;
              final score = sub?['score'] as num?;
              final passed = sub?['passed'] as bool?;
              return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isLocked ? AppColors.surfaceVariant : AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isLocked ? Colors.grey.withOpacity(0.12) : AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.quiz_rounded, color: isLocked ? Colors.grey : AppColors.primary, size: 22),
                    ),
                    title: Text(a.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isLocked ? Colors.grey : null)),
                    subtitle: Text(
                      '${a.questions.length} questions · Pass ${a.passScore}%'
                      '${a.timerMins != null ? ' · ⏱ ${a.timerMins} min' : ''}',
                      style: TextStyle(fontSize: 12, color: isLocked ? Colors.grey : null),
                    ),
                    trailing: isLocked 
                      ? const Icon(Icons.lock, color: Colors.grey)
                      : done
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${score?.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: passed == true ? AppColors.success : AppColors.error,
                                ),
                              ),
                              Text(passed == true ? 'Passed' : 'Failed',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: passed == true ? AppColors.success : AppColors.error,
                                  )),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.push('/assessment-quiz', extra: a);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Start', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                  ),
                );
            }

            return subAsync.when(
              loading: () => buildCard(null),
              error:   (_, __) => buildCard(null),
              data:    (sub)   => buildCard(sub),
            );
          },
        );
      },
    );
  }
}

// ── Information / Notes tab — real data from public.resources view ───────────

class _ResourceTab extends ConsumerWidget {
  final ProviderListenable<AsyncValue<List<Map<String, dynamic>>>> provider;
  final String emptyLabel;

  const _ResourceTab({required this.provider, required this.emptyLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);

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
                    emptyLabel == 'notes' ? Icons.notes_outlined : Icons.info_outline_rounded,
                    size: 56,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text('No $emptyLabel available', style: Theme.of(context).textTheme.titleSmall),
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
            final title = item['title'] as String? ?? '';
            final content = item['content'] as String? ?? '';
            final hasPdf = item['pdf_path'] != null;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                onTap: hasPdf ? () async {
                  final path = item['pdf_path'] as String;
                  String url = path;
                  if (!path.startsWith('http')) {
                    // Try to guess the bucket, or assume it's just 'resources'
                    try {
                      url = Supabase.instance.client.storage.from('resources').getPublicUrl(path);
                    } catch (e) {
                      url = Supabase.instance.client.storage.from(ApiConstants.lessonPdfsBucket).getPublicUrl(path);
                    }
                  }
                  
                  final uri = Uri.parse(url);
                  try {
                    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not launch PDF viewer')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error opening PDF: $e\\nURL: $url')),
                      );
                    }
                  }
                } : null,
                borderRadius: BorderRadius.circular(14),
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
                              color: hasPdf
                                  ? Colors.red.withOpacity(0.1)
                                  : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              hasPdf ? Icons.picture_as_pdf_outlined : Icons.article_outlined,
                              color: hasPdf ? Colors.red : AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          content,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (hasPdf) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withOpacity(0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_as_pdf, color: Colors.red, size: 14),
                              SizedBox(width: 6),
                              Text('PDF attached', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
