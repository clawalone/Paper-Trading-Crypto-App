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

  static const List<QuizQuestion> _stockQuestions = [
    QuizQuestion(
      question: 'What does "P/E Ratio" stand for?',
      options: ['Price-to-Earnings Ratio', 'Profit-to-Equity Ratio', 'Portfolio Expense Ratio', 'Public Enterprise Ratio'],
      correctIndex: 0,
      explanation: 'P/E Ratio measures a company\'s current share price relative to its per-share earnings.',
    ),
    QuizQuestion(
      question: 'What is an "After-Market Order (AMO)"?',
      options: ['An order queued outside regular market trading hours', 'An order placed only after 5:00 PM on Fridays', 'An order with guaranteed zero brokerage fees', 'An order for unlisted penny stocks'],
      correctIndex: 0,
      explanation: 'AMOs let investors place buy/sell orders when markets are closed, executed upon the opening bell.',
    ),
    QuizQuestion(
      question: 'What is a "Dividend" in stock investing?',
      options: ['A portion of company profits distributed to shareholders', 'A penalty tax charged by the exchange', 'The commission paid to an equity broker', 'A mandatory share buyback'],
      correctIndex: 0,
      explanation: 'Dividends are regular earnings distributions paid out by profitable companies to shareholders.',
    ),
    QuizQuestion(
      question: 'What is an ETF?',
      options: ['Exchange-Traded Fund tracking an index or asset basket', 'Electronic Transfer Facility for fast wires', 'Equity Total Forecast report', 'Emerging Tech Financing program'],
      correctIndex: 0,
      explanation: 'An ETF is an investment fund traded on stock exchanges, much like individual stocks (e.g. SPY, QQQ).',
    ),
    QuizQuestion(
      question: 'What is "Intraday Margin" trading (e.g. 5x leverage)?',
      options: ['Using broker leverage for positions squared off before close', 'Holding shares permanently with high loan interest', 'Trading only pre-market futures contracts', 'Guaranteed profit insurance'],
      correctIndex: 0,
      explanation: 'Intraday margin provides up to 5x purchasing power for day-trading positions during market hours.',
    ),
    QuizQuestion(
      question: 'Which index benchmarks 50 of the largest Indian companies?',
      options: ['NIFTY 50', 'S&P 500', 'DAX 40', 'FTSE 100'],
      correctIndex: 0,
      explanation: 'The NIFTY 50 is the benchmark Indian stock market index for large-cap companies listed on NSE.',
    ),
    QuizQuestion(
      question: 'Which benchmark tracks 500 of the largest US companies?',
      options: ['S&P 500', 'Dow 30', 'Russell 2000', 'Nasdaq Composite'],
      correctIndex: 0,
      explanation: 'The S&P 500 tracks 500 leading publicly traded companies in the United States.',
    ),
    QuizQuestion(
      question: 'What qualifies a company as a "Blue Chip" stock?',
      options: ['Well-established, financially stable, large market cap', 'A newly launched tech startup with high volatility', 'A micro-cap company under \$1 per share', 'A company that only trades on blue computer screens'],
      correctIndex: 0,
      explanation: 'Blue chip companies (e.g. Apple, Microsoft, Reliance, TCS) are renowned for stability and reliability.',
    ),
  ];

  static List<QuizQuestion> getDailyQuestions([bool isStock = false]) {
    final now = DateTime.now();
    // Use the days since epoch to select 4 questions
    final dayIndex = now.difference(DateTime.utc(2020, 1, 1)).inDays;
    
    // Seed a pseudo-random generator with the day index so it's consistent all day
    final seed = dayIndex + (isStock ? 7919 : 0);
    int a = seed * 1103515245 + 12345;
    
    List<QuizQuestion> daily = [];
    final pool = List<QuizQuestion>.from(isStock ? _stockQuestions : _allQuestions);
    
    for (int i = 0; i < 4; i++) {
      a = a * 1103515245 + 12345;
      final index = (a.abs() % pool.length);
      daily.add(pool[index]);
      pool.removeAt(index);
    }
    return daily;
  }
}
