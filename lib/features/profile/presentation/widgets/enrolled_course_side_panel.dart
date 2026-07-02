import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/quiz_model.dart';
import '../../../../shared/models/resource_model.dart';
import '../../../courses/presentation/providers/course_provider.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/api_constants.dart';

class EnrolledCourseSidePanel extends ConsumerWidget {
  final String courseId;

  const EnrolledCourseSidePanel({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppColors.background,
      width: MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Course Resources',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
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
                    _ResourcesTab(courseId: courseId, category: ResourceCategory.information),
                    _ResourcesTab(courseId: courseId, category: ResourceCategory.notes),
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

class _AssessmentTab extends ConsumerWidget {
  final String courseId;
  const _AssessmentTab({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(courseQuizzesProvider(courseId));
    final lessonsAsync = ref.watch(courseLessonsProvider(courseId));
    final completedLessonIdsAsync = ref.watch(completedLessonIdsProvider);

    return quizzesAsync.when(
      loading: () => const AppLoading(),
      error: (err, _) => AppError(message: err.toString()),
      data: (quizzes) {
        if (quizzes.isEmpty) {
          return const Center(child: Text('No assessments available.'));
        }

        final lessons = lessonsAsync.value ?? [];
        final completedLessonIds = completedLessonIdsAsync.value ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: quizzes.length,
          itemBuilder: (context, index) {
            final quiz = quizzes[index];
            final level = index + 1;
            
            // Locked if the corresponding lesson at this index has not been completed
            bool isLocked = false;
            if (lessons.length > index) {
              final currentLesson = lessons[index];
              isLocked = !completedLessonIds.contains(currentLesson.id);
            } else {
              // If there's no lesson, fallback to locking unless it's index 0?
              // Assuming 1:1 mapping, it will be locked if there's no lesson to complete.
              isLocked = index > 0;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: isLocked ? AppColors.surfaceVariant : AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text('Level $level: ${quiz.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(quiz.description ?? ''),
                trailing: isLocked
                    ? const Icon(Icons.lock, color: Colors.grey)
                    : const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: isLocked
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Starting ${quiz.title}...')),
                        );
                      },
              ),
            );
          },
        );
      },
    );
  }
}

class _ResourcesTab extends ConsumerWidget {
  final String courseId;
  final ResourceCategory category;

  const _ResourcesTab({required this.courseId, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resourcesAsync = ref.watch(courseResourcesProvider(courseId));

    return resourcesAsync.when(
      loading: () => const AppLoading(),
      error: (err, _) => AppError(message: err.toString()),
      data: (resources) {
        final filtered = resources.where((r) => r.category == category).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text('No ${category.name} available.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final resource = filtered[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: _buildIconForFileType(resource.fileType),
                title: Text(resource.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(resource.description ?? ''),
                trailing: const Icon(Icons.remove_red_eye, color: AppColors.primary),
                onTap: () {
                  // TODO: Open PDF/PPT viewer or launch URL
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opening read-only file: ${resource.title}')),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIconForFileType(String fileType) {
    IconData icon;
    Color color;
    switch (fileType.toLowerCase()) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'ppt':
      case 'pptx':
        icon = Icons.slideshow;
        color = Colors.orange;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }
}
