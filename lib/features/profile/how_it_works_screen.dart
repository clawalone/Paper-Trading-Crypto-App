import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../data/user_provider.dart';

class HowItWorksScreen extends ConsumerWidget {
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
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(content, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefLang = ref.watch(userProvider.select((s) => s.profile.preferredLanguage)).toLowerCase();
    final currentAppLang = AppTranslations.currentLanguage.toLowerCase();
    final localeCode = Localizations.maybeLocaleOf(context)?.languageCode;
    final bool isHi = prefLang.contains('hi') || currentAppLang.contains('hi') || localeCode == 'hi';
    final bool isEs = prefLang.contains('es') || prefLang.contains('span') || currentAppLang.contains('es') || localeCode == 'es';
    final lang = isHi ? 'hi' : (isEs ? 'es' : 'en');

    final String welcomeText;
    final List<(IconData, String, String)> sections;

    if (lang == 'hi') {
      welcomeText = 'अल्टीमेट क्रिप्टो ट्रेडिंग सिम्युलेटर में आपका स्वागत है! यहाँ सभी सुविधाओं और उनके उपयोग का पूरा विवरण दिया गया है।';
      sections = [
        (
          Icons.account_balance_wallet,
          'वर्चुअल बैलेंस और फंड का अनुरोध',
          'आप ट्रेड करने के लिए वर्चुअल बैलेंस के साथ शुरुआत करते हैं। क्योंकि यह एक सिम्युलेटर है, वास्तविक पैसे का उपयोग कभी नहीं किया जाता है। यदि आपका फंड खत्म हो जाता है या आप बड़े ट्रेड्स टेस्ट करना चाहते हैं, तो आप प्रोफ़ाइल टैब में "मनी रिक्वेस्ट" बटन पर टैप कर सकते हैं। यह "एडमिन" को एक सिमुलेटेड अनुरोध भेजता है, जो तुरंत आपकी पसंदीदा मुद्रा में आपके खाते में अधिक वर्चुअल पूंजी क्रेडिट कर सकता है।'
        ),
        (
          Icons.currency_exchange,
          'स्पॉट ट्रेडिंग (खरीदें और बेचें)',
          'मार्केट टैब में, आप कॉइन्स खोज सकते हैं और लाइव चार्ट देखने के लिए उन पर क्लिक कर सकते हैं। "खरीदें" पर टैप करके, आप अपने वर्चुअल बैलेंस का उपयोग करके कॉइन खरीद सकते हैं। कृपया ध्यान दें: सिम्युलेटर इंजन केवल कॉइन की पूर्ण संख्याओं को खरीदने का समर्थन करता है (उदा. 1 ETH, 2 BTC)। यदि आप ऐसा फिएट अमाउंट दर्ज करते हैं जो कम से कम 1 पूरा कॉइन खरीदने के लिए बहुत छोटा है, तो कन्फर्म बटन लॉक रहेगा।'
        ),
        (
          Icons.show_chart,
          'फ्यूचर्स ट्रेडिंग (प्रो)',
          'फ्यूचर्स आपको अपने लाभ या हानि को बढ़ाने के लिए लीवरेज (उधार ली गई वर्चुअल पूंजी) के साथ ट्रेड करने की सुविधा देता है।\n\n• लॉन्ग (खरीदें): आप भविष्यवाणी करते हैं कि कीमत ऊपर जाएगी।\n• शॉर्ट (बेचें): आप भविष्यवाणी करते हैं कि कीमत नीचे जाएगी।\n\nसावधान रहें: उच्च लीवरेज (125x तक) का उपयोग करने का अर्थ है कि आपके खिलाफ थोड़ा सा भी मूल्य संचलन "लिक्विडेशन" को ट्रिगर कर सकता है, जिससे उस ट्रेड के लिए आपका मार्जिन समाप्त हो जाता है।'
        ),
        (
          Icons.pie_chart,
          'पोर्टफोलियो और डैशबोर्ड',
          'आपका डैशबोर्ड आपको आपकी कुल कुल संपत्ति का संपूर्ण दृश्य प्रदान करता है, जो आपके उपलब्ध वर्चुअल कैश और आपके पास मौजूद सभी कॉइनों के वर्तमान लाइव मूल्य को जोड़ता है। पोर्टफोलियो टैब आपकी व्यक्तिगत संपत्तियों का एक विस्तृत विश्लेषण प्रदान करता है, जो वर्तमान बाजार मूल्य की तुलना में आपके औसत खरीद मूल्य को दर्शाता है और आपके लाइव PNL (लाभ और हानि) की गणना करता है।'
        ),
        (
          Icons.newspaper,
          'लाइव मार्केट समाचार',
          'न्यूज टैब स्वचालित रूप से कॉइनटेलीग्राफ और कॉइनडेस्क जैसे प्रमुख क्रिप्टो प्रकाशकों से रीयल-टाइम समाचार लेख एकत्र करता है। नवीनतम ब्रेकिंग न्यूज प्राप्त करने और अपने सिमुलेटेड ट्रेड करने से पहले सूचित रहने के लिए पुल-टू-रिफ्रेश करें।'
        ),
      ];
    } else if (lang == 'es') {
      welcomeText = '¡Bienvenido al mejor simulador de trading cripto! Aquí tienes un desglose de todas las funciones y cómo utilizarlas.';
      sections = [
        (
          Icons.account_balance_wallet,
          'Saldo virtual y solicitud de fondos',
          'Comienzas con un saldo virtual para operar. Como se trata de un simulador, nunca se utiliza dinero real. Si te quedas sin fondos o quieres probar operaciones más grandes, puedes tocar el botón "Solicitar dinero" en la pestaña Perfil. Esto envía una solicitud simulada al "Admin", quien puede acreditar instantáneamente más capital virtual en tu cuenta en tu moneda preferida.'
        ),
        (
          Icons.currency_exchange,
          'Trading Spot (Comprar y Vender)',
          'En la pestaña Mercado, puedes buscar monedas y hacer clic en ellas para ver gráficos en vivo. Al tocar "Comprar", puedes adquirir monedas utilizando tu saldo virtual. Ten en cuenta: el motor del simulador solo admite la compra de números enteros de monedas (por ejemplo, 1 ETH, 2 BTC). Si ingresas una cantidad fiat demasiado pequeña para comprar al menos 1 moneda entera, el botón de Confirmar permanecerá bloqueado.'
        ),
        (
          Icons.show_chart,
          'Trading de Futuros (Pro)',
          'Los futuros te permiten operar con apalancamiento (fondos virtuales prestados) para amplificar tus ganancias o pérdidas.\n\n• Largo (Comprar): Predices que el precio SUBIRÁ.\n• Corto (Vender): Predices que el precio BAJARÁ.\n\nTen cuidado: usar un alto apalancamiento (hasta 125x) significa que incluso un pequeño movimiento del precio en tu contra puede provocar una "Liquidación", que agota tu margen para esa operación.'
        ),
        (
          Icons.pie_chart,
          'Portafolio y Panel',
          'Tu panel de control te ofrece una vista panorámica de tu patrimonio neto total, combinando tu efectivo virtual disponible con el valor en vivo de todas las monedas que posees. La pestaña Portafolio detalla tus activos individuales, comparando tu precio promedio de compra con el precio de mercado actual para calcular tu PnL (ganancias y pérdidas) en tiempo real.'
        ),
        (
          Icons.newspaper,
          'Noticias del mercado en vivo',
          'La pestaña Noticias recopila automáticamente artículos de noticias en tiempo real de los principales medios cripto como CoinTelegraph y CoinDesk. Desliza hacia abajo para actualizar y estar siempre informado antes de realizar tus operaciones simuladas.'
        ),
      ];
    } else {
      welcomeText = 'Welcome to the Ultimate Crypto Trading Simulator! Here is a breakdown of all the features and how to use them.';
      sections = [
        (
          Icons.account_balance_wallet,
          'Virtual Balance & Requesting Funds',
          'You start with a virtual balance to trade with. Because this is a simulator, no real money is ever used. If you run out of funds or want to test larger trades, you can tap the "Request Money" button in the Profile tab. This sends a simulated request to the "Admin", who can instantly credit your account with more virtual capital in your preferred currency.'
        ),
        (
          Icons.currency_exchange,
          'Spot Trading (Buy & Sell)',
          'In the Market tab, you can search for coins and click on them to view live charts. By tapping "Buy", you can purchase coins using your virtual balance. Please note: The simulator engine only supports buying whole numbers of coins (e.g., 1 ETH, 2 BTC). If you enter a fiat amount that is too small to buy at least 1 whole coin, the Confirm button will remain locked.'
        ),
        (
          Icons.show_chart,
          'Futures Trading (Pro)',
          'Futures allow you to trade with Leverage (borrowed virtual funds) to amplify your profits or losses. \n\n• Long (Buy): You predict the price will go UP.\n• Short (Sell): You predict the price will go DOWN.\n\nBe careful: Using high leverage (up to 125x) means even a small price movement against you can trigger a "Liquidation," which wipes out your margin for that trade.'
        ),
        (
          Icons.pie_chart,
          'Portfolio & Dashboard',
          'Your Dashboard gives you a bird\'s-eye view of your total net worth, which combines your available virtual cash and the current live value of all the coins you own. The Portfolio tab provides a detailed breakdown of your individual assets, showing your Average Buy Price compared to the Current Market Price, calculating your live PNL (Profit and Loss).'
        ),
        (
          Icons.newspaper,
          'Live Market News',
          'The News tab automatically aggregates real-time news articles from major crypto publishers like CoinTelegraph and CoinDesk. Pull-to-refresh to fetch the absolute latest breaking news and stay informed before making your simulated trades.'
        ),
      ];
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('How It Works'.tr(), style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              welcomeText,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            for (final sec in sections)
              _buildSection(sec.$2.toLowerCase(), sec.$1, sec.$2, sec.$3),
            const SizedBox(height: 40),
            Center(
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check, color: Colors.black),
                label: Text('Got it!'.tr(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
