import 'dart:io';
import 'dart:math';

void main() async {
  print('Removing old .git directory...');
  final gitDir = Directory('.git');
  if (await gitDir.exists()) {
    await gitDir.delete(recursive: true);
  }

  print('Initializing new git repository...');
  await Process.run('git', ['init']);

  final startDate = DateTime(2026, 3, 23);
  final endDate = DateTime.now(); // Today
  final random = Random();

  var currentDate = startDate;
  final dummyFile = File('.history_log');
  
  print('Generating history...');

  int totalCommits = 0;

  while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
    // 15% chance of a break day
    bool isBreakDay = random.nextDouble() < 0.15;
    
    // Skip some Sundays (e.g., 50% of Sundays)
    bool isSunday = currentDate.weekday == DateTime.sunday;
    if (isSunday && random.nextDouble() < 0.5) {
      isBreakDay = true;
    }

    if (!isBreakDay) {
      int commitsToday = random.nextInt(4) + 1; // 1 to 4 commits
      
      for (int i = 0; i < commitsToday; i++) {
        int hour = 9 + random.nextInt(9);
        int minute = random.nextInt(60);
        int second = random.nextInt(60);
        
        final commitDate = DateTime(
          currentDate.year, currentDate.month, currentDate.day,
          hour, minute, second
        );

        await dummyFile.writeAsString('Commit at ${commitDate.toIso8601String()}\n', mode: FileMode.append);
        
        await Process.run('git', ['add', '.history_log']);
        
        final dateStr = commitDate.toIso8601String();
        final env = {
          'GIT_AUTHOR_DATE': dateStr,
          'GIT_COMMITTER_DATE': dateStr,
        };
        
        await Process.run('git', ['commit', '-m', 'Update history log', '--date', dateStr], environment: env);
        totalCommits++;
      }
    }

    currentDate = currentDate.add(const Duration(days: 1));
  }
  
  print('Generated $totalCommits fake commits.');
  
  print('Cleaning up dummy file...');
  if (await dummyFile.exists()) {
    await Process.run('git', ['rm', '-f', '.history_log']);
    final dateStr = DateTime.now().toIso8601String();
    final env = {
      'GIT_AUTHOR_DATE': dateStr,
      'GIT_COMMITTER_DATE': dateStr,
    };
    await Process.run('git', ['commit', '-m', 'Clean up history log', '--date', dateStr], environment: env);
  }
  
  print('Adding actual project files...');
  await Process.run('git', ['add', '.']);
  final finalDate = DateTime.now().toIso8601String();
  final envFinal = {
    'GIT_AUTHOR_DATE': finalDate,
    'GIT_COMMITTER_DATE': finalDate,
  };
  await Process.run('git', ['commit', '-m', 'Initial project commit', '--date', finalDate], environment: envFinal);
  
  print('Done! Ready to push.');
}
