import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last Updated: Today',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Nature of the Application',
              'Paper Trading - Crypto is strictly a paper-trading simulator and educational tool. It is designed to simulate cryptocurrency market mechanics, including spot trading, futures trading, and portfolio management. Paper Trading - Crypto is NOT an exchange, brokerage, or financial institution.',
            ),
            _buildSection(
              '2. Virtual Currency & No Real Money',
              'All funds, balances, rewards, and assets displayed within Paper Trading - Crypto are entirely virtual and simulated. You cannot deposit, withdraw, or transfer real money or real cryptocurrencies into or out of Paper Trading - Crypto. The virtual currency has zero real-world monetary value and cannot be exchanged for fiat currency or other assets.',
            ),
            _buildSection(
              '3. Not Financial Advice',
              'The information, tools, and simulated market data provided by Paper Trading - Crypto do not constitute financial, investment, legal, or tax advice. Any trading strategies you test or execute within Paper Trading - Crypto are for educational and entertainment purposes only. Past simulated performance is not indicative of future real-world results.',
            ),
            _buildSection(
              '4. Market Data Accuracy',
              'Paper Trading - Crypto pulls market pricing, news, and other data from third-party public sources (such as Binance and CoinTelegraph). While we strive for accuracy, we make no guarantees regarding the timeliness, precision, or reliability of this data. Delays, inaccuracies, or downtime in third-party feeds may occur.',
            ),
            _buildSection(
              '5. Simulated Features & Mechanics',
              'Features such as "Request Money", "Buy", "Sell", "Long", "Short", and "Liquidations" operate strictly within the bounds of Paper Trading - Crypto\'s simulation software. Requesting money from the "Admin" merely credits your virtual account with simulated funds and does not involve real banking or financial networks.',
            ),
            _buildSection(
              '6. High Leverage & Risk Warnings',
              'Paper Trading - Crypto allows users to experiment with simulated leverage (up to 125x) in Futures Trading. Please be aware that real-world trading with high leverage involves extreme financial risk and can lead to rapid total loss of capital. High virtual win rates in Paper Trading - Crypto do not guarantee success in live cryptocurrency exchanges.',
            ),
            _buildSection(
              '7. Community Hub & User Content',
              'When participating in the Community Hub (posting trades, commenting, voting on price predictions, or sending virtual tips), you agree not to publish illegal, offensive, spam, or misleading content. Virtual tips are purely symbolic within the simulation. We reserve the right to remove any post or comment that violates community standards.',
            ),
            _buildSection(
              '8. Weekly Championships, Arena & XP',
              'Tournaments, 1v1 Arena Duels, leaderboards, XP points, streaks, and badges within Paper Trading - Crypto are gamified features designed for fun and skill building. Winning tournaments or achieving top ranks confers no monetary cash prize, real crypto payouts, or legal compensation.',
            ),
            _buildSection(
              '9. Limitation of Liability',
              'Under no circumstances shall the creators, developers, or operators of Paper Trading - Crypto be held liable for any real-world financial losses or damages resulting from the use of this simulator, your reliance on simulated market data, or the application of strategies tested within Paper Trading - Crypto to actual real-world trading platforms.',
            ),
            _buildSection(
              '10. User Conduct & System Integrity',
              'You agree to use Paper Trading - Crypto solely for its intended educational purposes. You must not attempt to manipulate the simulation engine, exploit system bugs to artificially inflate virtual balances, deploy automated scraping bots, or reverse engineer Paper Trading - Crypto\'s data infrastructure.',
            ),
            _buildSection(
              '11. Account Security & Right to Terminate',
              'You are responsible for keeping your login credentials secure. We reserve the right to suspend, restrict, or terminate user accounts that violate these Terms & Conditions, engage in toxic behavior in the Community Hub, or disrupt service operation.',
            ),
            _buildSection(
              '12. Modifications to Terms',
              'We reserve the right to update or modify these Terms & Conditions at any time. Continued use of Paper Trading - Crypto following any updates constitutes full acceptance of the revised terms.',
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'By using Paper Trading - Crypto, you accept these terms in full.',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
