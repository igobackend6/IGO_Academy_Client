import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/quiz_model.dart';
import '../../../../shared/models/resource_model.dart';
import '../../../courses/presentation/providers/course_provider.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';

// Dummy provider for resources, since it's not in the repository yet.
final courseResourcesProvider = FutureProvider.family<List<ResourceModel>, String>((ref, courseId) async {
  await Future.delayed(const Duration(seconds: 1)); // simulate network
  return [
    ResourceModel(
      id: '1',
      courseId: courseId,
      title: 'Irrigation Syllabus Info',
      description: 'Here the full notes pdf for smart irrigation.',
      fileUrl: 'https://example.com/info.pdf',
      fileType: 'pdf',
      category: ResourceCategory.information,
    ),
    ResourceModel(
      id: '2',
      courseId: courseId,
      title: 'Smart Farming Notes',
      description: 'Detailed notes on smart farming.',
      fileUrl: 'https://example.com/notes.pdf',
      fileType: 'pdf',
      category: ResourceCategory.notes,
    ),
  ];
});

// Dummy provider for quizzes to mock Level 1 and Level 2
final courseQuizzesProvider = FutureProvider.family<List<QuizModel>, String>((ref, courseId) async {
  await Future.delayed(const Duration(seconds: 1));
  return [
    QuizModel(
      id: 'q1',
      courseId: courseId,
      title: 'Level 1 Assessment',
      description: 'Basic assessment for this course.',
      totalQuestions: 10,
    ),
    QuizModel(
      id: 'q2',
      courseId: courseId,
      title: 'Level 2 Assessment',
      description: 'Advanced assessment. Unlocked after Level 1.',
      totalQuestions: 15,
    ),
  ];
});

// Dummy provider for checking if Level 1 is passed
final isLevel1PassedProvider = FutureProvider.family<bool, String>((ref, courseId) async {
  await Future.delayed(const Duration(seconds: 1));
  return false; // Assuming not passed by default for demo
});

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
    final isLevel1PassedAsync = ref.watch(isLevel1PassedProvider(courseId));

    return quizzesAsync.when(
      loading: () => const AppLoading(),
      error: (err, _) => AppError(message: err.toString()),
      data: (quizzes) {
        if (quizzes.isEmpty) {
          return const Center(child: Text('No assessments available.'));
        }

        final isLevel1Passed = isLevel1PassedAsync.value ?? false;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: quizzes.length,
          itemBuilder: (context, index) {
            final quiz = quizzes[index];
            final isLevel2 = index == 1; // Assuming 2nd quiz is level 2
            final isLocked = isLevel2 && !isLevel1Passed;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              color: isLocked ? AppColors.surfaceVariant : AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(quiz.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(quiz.description ?? ''),
                trailing: isLocked
                    ? const Icon(Icons.lock, color: Colors.grey)
                    : ElevatedButton(
                        onPressed: () {
                          // TODO: Navigate to quiz attempt
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Start'),
                      ),
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
