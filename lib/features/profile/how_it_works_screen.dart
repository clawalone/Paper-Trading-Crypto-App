import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  Widget _buildSection(String iconName, IconData icon, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(content, style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5)),
              ],
            ),
          ),
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
        title: const Text('How It Works', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to the Ultimate Crypto Trading Simulator! Here is a breakdown of all the features and how to use them.',
              style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'wallet',
              Icons.account_balance_wallet,
              'Virtual Balance & Requesting Funds',
              'You start with a virtual balance to trade with. Because this is a simulator, no real money is ever used. If you run out of funds or want to test larger trades, you can tap the "Request Money" button in the Profile tab. This sends a simulated request to the "Admin", who can instantly credit your account with more virtual capital in your preferred currency.',
            ),
            _buildSection(
              'spot',
              Icons.currency_exchange,
              'Spot Trading (Buy & Sell)',
              'In the Market tab, you can search for coins and click on them to view live charts. By tapping "Buy", you can purchase coins using your virtual balance. Please note: The simulator engine only supports buying whole numbers of coins (e.g., 1 ETH, 2 BTC). If you enter a fiat amount that is too small to buy at least 1 whole coin, the Confirm button will remain locked.',
            ),
            _buildSection(
              'futures',
              Icons.show_chart,
              'Futures Trading (Pro)',
              'Futures allow you to trade with Leverage (borrowed virtual funds) to amplify your profits or losses. \n\n• Long (Buy): You predict the price will go UP.\n• Short (Sell): You predict the price will go DOWN.\n\nBe careful: Using high leverage (up to 125x) means even a small price movement against you can trigger a "Liquidation," which wipes out your margin for that trade.',
            ),
            _buildSection(
              'portfolio',
              Icons.pie_chart,
              'Portfolio & Dashboard',
              'Your Dashboard gives you a bird\'s-eye view of your total net worth, which combines your available virtual cash and the current live value of all the coins you own. The Portfolio tab provides a detailed breakdown of your individual assets, showing your Average Buy Price compared to the Current Market Price, calculating your live PNL (Profit and Loss).',
            ),
            _buildSection(
              'news',
              Icons.newspaper,
              'Live Market News',
              'The News tab automatically aggregates real-time news articles from major crypto publishers like CoinTelegraph and CoinDesk. Pull-to-refresh to fetch the absolute latest breaking news and stay informed before making your simulated trades.',
            ),
            const SizedBox(height: 40),
            Center(
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check, color: Colors.black),
                label: const Text('Got it!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(200, 50),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
