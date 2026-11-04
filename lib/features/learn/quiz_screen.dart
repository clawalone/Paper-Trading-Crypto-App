import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../data/quiz_data.dart';
import '../../data/user_provider.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOptionIndex;
  bool _hasSubmitted = false;

  late final List<QuizQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _questions = QuizData.getDailyQuestions();
  }

  void _submitAnswer() {
    if (_selectedOptionIndex == null) return;
    
    setState(() {
      _hasSubmitted = true;
      if (_selectedOptionIndex == _questions[_currentIndex].correctIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _hasSubmitted = false;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    final passed = _score >= 3; // 3 out of 4 to pass
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2329),
        title: Text(
          passed ? 'Quiz Passed!' : 'Quiz Failed',
          style: TextStyle(color: passed ? AppColors.profit : AppColors.loss, fontWeight: FontWeight.bold),
        ),
        content: Text(
          passed 
            ? 'Great job! You scored $_score/${_questions.length}. You earned 120 XP!'
            : 'You scored $_score/${_questions.length}. You need at least 3 correct to pass. Keep learning and try again!',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // go back to rewards screen
              if (passed) {
                ref.read(userProvider.notifier).completeQuiz();
              }
              ref.read(userProvider.notifier).recordQuizAttempt();
            },
            child: const Text('Back to Rewards', style: TextStyle(color: AppColors.primary)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} of ${_questions.length}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_currentIndex) / _questions.length,
                backgroundColor: const Color(0xFF2B3139),
                color: AppColors.primary,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 32),
              Text(
                question.question,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 32),
              ...List.generate(question.options.length, (index) {
                final isSelected = _selectedOptionIndex == index;
                final isCorrect = index == question.correctIndex;
                
                Color borderColor = const Color(0xFF2B3139);
                Color bgColor = const Color(0xFF1E2329);
                
                if (_hasSubmitted) {
                  if (isCorrect) {
                    borderColor = AppColors.profit;
                    bgColor = AppColors.profit.withOpacity(0.1);
                  } else if (isSelected && !isCorrect) {
                    borderColor = AppColors.loss;
                    bgColor = AppColors.loss.withOpacity(0.1);
                  }
                } else if (isSelected) {
                  borderColor = AppColors.primary;
                  bgColor = AppColors.primary.withOpacity(0.1);
                }

                return GestureDetector(
                  onTap: _hasSubmitted ? null : () {
                    setState(() {
                      _selectedOptionIndex = index;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(color: borderColor, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            question.options[index],
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_hasSubmitted && isCorrect)
                          const Icon(Icons.check_circle, color: AppColors.profit),
                        if (_hasSubmitted && isSelected && !isCorrect)
                          const Icon(Icons.cancel, color: AppColors.loss),
                      ],
                    ),
                  ),
                );
              }),
              
              if (_hasSubmitted) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B3139),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Explanation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(question.explanation, style: const TextStyle(color: Color(0xFF848E9C))),
                    ],
                  ),
                ),
              ],
              
              const Spacer(),
              ElevatedButton(
                onPressed: _selectedOptionIndex == null ? null : (_hasSubmitted ? _nextQuestion : _submitAnswer),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF2B3139),
                  disabledForegroundColor: const Color(0xFF6B7280),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _hasSubmitted 
                    ? (_currentIndex < _questions.length - 1 ? 'Next Question' : 'Finish Quiz') 
                    : 'Submit Answer',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
