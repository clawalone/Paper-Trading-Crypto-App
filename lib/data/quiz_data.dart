class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class QuizData {
  static const List<QuizQuestion> _allQuestions = [
    QuizQuestion(
      question: 'What is a "Bull Market"?',
      options: ['A market where prices are falling', 'A market where prices are rising', 'A market that stays flat', 'A market only for livestock'],
      correctIndex: 1,
      explanation: 'A bull market is characterized by rising prices and optimism among investors.',
    ),
    QuizQuestion(
      question: 'What does "Going Long" mean in futures trading?',
      options: ['Buying an asset expecting its price to rise', 'Selling an asset expecting its price to fall', 'Holding a coin for more than 5 years', 'Waiting a long time for a trade to execute'],
      correctIndex: 0,
      explanation: 'Going long means you are buying a contract with the expectation that the asset\'s price will increase.',
    ),
    QuizQuestion(
      question: 'What is "Leverage"?',
      options: ['A physical tool used to mine Bitcoin', 'A guaranteed way to make profit without risk', 'Using borrowed capital to increase potential return', 'The speed at which a blockchain processes data'],
      correctIndex: 2,
      explanation: 'Leverage lets you trade with more money than you actually have, amplifying both potential profits and potential losses.',
    ),
    QuizQuestion(
      question: 'Which of these is the safest way to store large amounts of cryptocurrency?',
      options: ['Leave it on an exchange', 'A hardware wallet (Cold storage)', 'Print out the password on a piece of paper', 'A mobile app wallet'],
      correctIndex: 1,
      explanation: 'Hardware wallets keep your private keys offline, protecting your assets from online hacks and malware.',
    ),
    QuizQuestion(
      question: 'What is a "Bear Market"?',
      options: ['A market where prices are falling', 'A market where prices are rising', 'A market that stays flat', 'A market only for wildlife'],
      correctIndex: 0,
      explanation: 'A bear market is characterized by falling prices and pessimism among investors.',
    ),
    QuizQuestion(
      question: 'What does "Shorting" mean?',
      options: ['Selling an asset you don\'t own expecting its price to fall', 'Buying an asset expecting its price to rise', 'Trading only for a short time', 'Buying fractions of a coin'],
      correctIndex: 0,
      explanation: 'Shorting or going short means you expect the asset\'s price to decrease.',
    ),
    QuizQuestion(
      question: 'What is a "Limit Order"?',
      options: ['An order to buy or sell at a specific price or better', 'An order to buy immediately at the current market price', 'An order that limits your losses', 'An order that limits the number of coins you can buy'],
      correctIndex: 0,
      explanation: 'A limit order guarantees the price but not the execution, as the market must reach your limit price.',
    ),
    QuizQuestion(
      question: 'What does "ROI" stand for?',
      options: ['Return on Investment', 'Rate of Interest', 'Risk of Inflation', 'Return on Income'],
      correctIndex: 0,
      explanation: 'ROI measures the profitability of an investment as a percentage of the original cost.',
    ),
    QuizQuestion(
      question: 'What is "Market Capitalization"?',
      options: ['The total value of all coins in circulation', 'The price of a single coin', 'The amount of money invested by the founders', 'The trading volume in 24 hours'],
      correctIndex: 0,
      explanation: 'Market Cap is calculated by multiplying the current price of a single coin by its total circulating supply.',
    ),
    QuizQuestion(
      question: 'What is a "Stop-Loss"?',
      options: ['An order to close a losing position at a specific price', 'A strategy to never lose money', 'A feature that prevents you from logging in', 'A guarantee of profit'],
      correctIndex: 0,
      explanation: 'A stop-loss order helps manage risk by automatically closing a position if the price moves against you.',
    ),
    QuizQuestion(
      question: 'What does "HODL" mean in crypto?',
      options: ['Hold On for Dear Life (Don\'t sell)', 'Highly Overvalued Digital Ledger', 'Hiding Online Digital Logs', 'Hacking Of Digital Ledgers'],
      correctIndex: 0,
      explanation: 'HODL originated from a typo of "hold" and became a popular acronym for holding cryptocurrency long-term.',
    ),
    QuizQuestion(
      question: 'What is a "Wallet Address"?',
      options: ['A string of letters and numbers used to send and receive crypto', 'Your home address', 'An email address', 'A password'],
      correctIndex: 0,
      explanation: 'A wallet address is like a bank account number that others can use to send you cryptocurrency.',
    ),
  ];

  static List<QuizQuestion> getDailyQuestions() {
    final now = DateTime.now();
    // Use the days since epoch to select 4 questions
    final dayIndex = now.difference(DateTime.utc(2020, 1, 1)).inDays;
    
    // Seed a pseudo-random generator with the day index so it's consistent all day
    final seed = dayIndex;
    int a = seed * 1103515245 + 12345;
    
    List<QuizQuestion> daily = [];
    final pool = List<QuizQuestion>.from(_allQuestions);
    
    for (int i = 0; i < 4; i++) {
      a = a * 1103515245 + 12345;
      final index = (a.abs() % pool.length);
      daily.add(pool[index]);
      pool.removeAt(index);
    }
    return daily;
  }
}
