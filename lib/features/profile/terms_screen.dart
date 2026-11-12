import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../data/user_provider.dart';
import 'privacy_policy_screen.dart';

class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(content, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
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

    final String lastUpdatedText;
    final String acceptText;
    final List<(String, String)> sections;

    if (lang == 'hi') {
      lastUpdatedText = 'अंतिम अपडेट: आज';
      acceptText = 'PaperTrading - Crypto & Stocks का उपयोग करके, आप इन शर्तों को पूर्ण रूप से स्वीकार करते हैं।';
      sections = [
        (
          '1. एप्लिकेशन की प्रकृति',
          'PaperTrading - Crypto & Stocks पूरी तरह से एक पेपर-ट्रेडिंग सिम्युलेटर और शैक्षिक उपकरण है। इसे क्रिप्टोक्यूरेंसी मार्केट मैकेनिक्स का अनुकरण करने के लिए डिज़ाइन किया गया है, जिसमें स्पॉट ट्रेडिंग, फ्यूचर्स ट्रेडिंग और पोर्टफोलियो प्रबंधन शामिल हैं। PaperTrading - Crypto & Stocks कोई एक्सचेंज, ब्रोकरेज या वित्तीय संस्थान नहीं है।'
        ),
        (
          '2. वर्चुअल करेंसी और वास्तविक धन की अनुपस्थिति',
          'PaperTrading - Crypto & Stocks के भीतर प्रदर्शित सभी फंड, बैलेंस, पुरस्कार और संपत्तियां पूरी तरह से आभासी और सिमुलेटेड हैं। आप PaperTrading - Crypto & Stocks में वास्तविक धन या वास्तविक क्रिप्टोकरेंसी जमा, निकाल या स्थानांतरित नहीं कर सकते हैं। वर्चुअल मुद्रा का कोई वास्तविक मौद्रिक मूल्य नहीं है और इसे फिएट मुद्रा या अन्य संपत्तियों के लिए नहीं बदला जा सकता है।'
        ),
        (
          '3. वित्तीय सलाह नहीं और CFTC नियम 4.41 प्रकटीकरण',
          'PaperTrading - Crypto & Stocks द्वारा प्रदान की गई जानकारी, उपकरण, एल्गोरिथम मॉडल और सिमुलेटेड मार्केट डेटा वित्तीय, निवेश, कानूनी या कर सलाह का गठन नहीं करते हैं। PaperTrading - Crypto & Stocks एक पंजीकृत निवेश सलाहकार, कमोडिटी ट्रेडिंग सलाहकार या ब्रोकर नहीं है।\n\nCFTC नियम 4.41 सूचना: काल्पनिक या सिमुलेटेड प्रदर्शन परिणामों की कुछ अंतर्निहित सीमाएं होती हैं। वास्तविक प्रदर्शन रिकॉर्ड के विपरीत, सिमुलेटेड परिणाम वास्तविक ट्रेडिंग का प्रतिनिधित्व नहीं करते हैं। इसके अलावा, चूंकि ट्रेड वास्तव में निष्पादित नहीं किए गए हैं, इसलिए परिणाम कुछ बाजार कारकों जैसे कि तरलता की कमी के प्रभाव के लिए कम या अधिक क्षतिपूर्ति कर सकते हैं।'
        ),
        (
          '4. मार्केट डेटा की सटीकता',
          'PaperTrading - Crypto & Stocks तीसरे पक्ष के सार्वजनिक स्रोतों (जैसे बिनेंस और कॉइनटेलीग्राफ) से मूल्य निर्धारण, समाचार और अन्य डेटा प्राप्त करता है। यद्यपि हम सटीकता के लिए प्रयास करते हैं, हम इस डेटा की समयबद्धता, सटीकता या विश्वसनीयता के संबंध में कोई गारंटी नहीं देते हैं।'
        ),
        (
          '5. सिमुलेटेड सुविधाएं और मैकेनिक्स',
          '"रिक्वेस्ट मनी", "बाय", "सेल", "लॉन्ग", "शॉर्ट" और "लिक्विडेशन" जैसी सुविधाएं पूरी तरह से PaperTrading - Crypto & Stocks के सिमुलेशन सॉफ्टवेयर के दायरे में काम करती हैं। "एडमिन" से पैसे का अनुरोध केवल आपके वर्चुअल खाते में सिमुलेटेड फंड जमा करता है और इसमें कोई वास्तविक बैंकिंग या वित्तीय नेटवर्क शामिल नहीं होता है।'
        ),
        (
          '6. उच्च लीवरेज और जोखिम चेतावनियां',
          'PaperTrading - Crypto & Stocks उपयोगकर्ताओं को फ्यूचर्स ट्रेडिंग में सिमुलेटेड लीवरेज (125x तक) का परीक्षण करने की अनुमति देता है। कृपया ध्यान रखें कि उच्च लीवरेज के साथ वास्तविक ट्रेडिंग में अत्यधिक वित्तीय जोखिम शामिल होता है और इससे पूंजी का तेजी से पूर्ण नुकसान हो सकता है।'
        ),
        (
          '7. कम्युनिटी हब और शून्य-सहिष्णुता नीति',
          'कम्युनिटी हब में भाग लेते समय, आप हमारी सख्त आचार संहिता से सहमत होते हैं। PaperTrading - Crypto & Stocks आपत्तिजनक सामग्री, घृणास्पद भाषण, उत्पीड़न, प्रतिरूपण, अश्लील सामग्री, धोखाधड़ी या अपमानजनक आचरण के खिलाफ शून्य-सहिष्णुता नीति लागू करता है। उल्लंघन करने वाले किसी भी उपयोगकर्ता की सामग्री तुरंत हटा दी जाएगी और उनका खाता बिना किसी पूर्व सूचना के स्थायी रूप से समाप्त कर दिया जाएगा।'
        ),
        (
          '8. साप्ताहिक चैंपियनशिप, एरिना और XP',
          'टूर्नामेंट, 1v1 एरिना द्वंद्व, लीडरबोर्ड, XP अंक, स्ट्रीक और बैज मनोरंजन और कौशल निर्माण के लिए डिज़ाइन की गई गेमिफाइड सुविधाएं हैं। टूर्नामेंट जीतने या शीर्ष रैंक प्राप्त करने से कोई नकद पुरस्कार या वास्तविक मौद्रिक लाभ नहीं मिलता है।'
        ),
        (
          '9. दायित्व की सीमा',
          'किसी भी परिस्थिति में PaperTrading - Crypto & Stocks के निर्माता, डेवलपर या ऑपरेटर इस सिम्युलेटर के उपयोग से होने वाले किसी भी वास्तविक वित्तीय नुकसान या क्षति के लिए उत्तरदायी नहीं होंगे।'
        ),
        (
          '10. उपयोगकर्ता आचरण और सिस्टम अखंडता',
          'आप केवल इसके इच्छित शैक्षिक उद्देश्यों के लिए PaperTrading - Crypto & Stocks का उपयोग करने के लिए सहमत हैं। आपको सिमुलेशन इंजन में हेरफेर करने, वर्चुअल बैलेंस बढ़ाने के लिए सिस्टम बग का फायदा उठाने या ऑटोमेटेड बॉट तैनात करने का प्रयास नहीं करना चाहिए।'
        ),
        (
          '11. खाता सुरक्षा और समाप्त करने का अधिकार',
          'आप अपने लॉगिन क्रेडेंशियल सुरक्षित रखने के लिए जिम्मेदार हैं। हम उन उपयोगकर्ता खातों को निलंबित, प्रतिबंधित या समाप्त करने का अधिकार सुरक्षित रखते हैं जो इन नियमों और शर्तों का उल्लंघन करते हैं।'
        ),
        (
          '12. शर्तों में संशोधन',
          'हम किसी भी समय इन नियमों और शर्तों को अपडेट या संशोधित करने का अधिकार सुरक्षित रखते हैं। किसी भी अपडेट के बाद PaperTrading - Crypto & Stocks का निरंतर उपयोग संशोधित शर्तों की पूर्ण स्वीकृति का गठन करता है।'
        ),
        (
          '13. गोपनीयता और डेटा सुरक्षा',
          'आपकी गोपनीयता हमारे लिए आवश्यक है। खाता जानकारी और सिमुलेशन स्थिति की सुरक्षा कैसे की जाती है, इसके पूर्ण विवरण के लिए कृपया हमारी व्यापक गोपनीयता नीति की समीक्षा करें।'
        ),
        (
          '14. तृतीय-पक्ष ट्रेडमार्क और बौद्धिक संपदा',
          'इस एप्लिकेशन में प्रदर्शित सभी उत्पाद नाम, लोगो और ट्रेडमार्क उनके संबंधित स्वामियों की संपत्ति हैं। किसी भी तृतीय-पक्ष उत्पाद या सेवा का संदर्भ उनके द्वारा संबद्धता, समर्थन या प्रायोजन का संकेत नहीं देता है।'
        ),
        (
          '15. पात्रता और आयु आवश्यकता (18+)',
          'उन्नत वित्तीय डेरिवेटिव सिमुलेशन और सार्वजनिक समुदाय सुविधाओं की उपस्थिति के कारण PaperTrading - Crypto & Stocks विशेष रूप से 18 वर्ष या उससे अधिक आयु के व्यक्तियों के लिए अभिप्रेत है। इस एप्लिकेशन का उपयोग करके, आप पुष्टि करते हैं कि आप इस आयु आवश्यकता को पूरा करते हैं।'
        ),
      ];
    } else if (lang == 'es') {
      lastUpdatedText = 'Última actualización: Hoy';
      acceptText = 'Al usar PaperTrading - Crypto & Stocks, aceptas estos términos en su totalidad.';
      sections = [
        (
          '1. Naturaleza de la aplicación',
          'PaperTrading - Crypto & Stocks es estrictamente un simulador de trading simulado y una herramienta educativa. Está diseñado para simular los mecanismos del mercado de criptomonedas, incluido el trading spot, el trading de futuros y la gestión de portafolios. PaperTrading - Crypto & Stocks NO es una casa de cambio, un corredor ni una institución financiera.'
        ),
        (
          '2. Moneda virtual y sin dinero real',
          'Todos los fondos, saldos, recompensas y activos que se muestran en PaperTrading - Crypto & Stocks son completamente virtuales y simulados. No puedes depositar, retirar ni transferir dinero real ni criptomonedas reales dentro o fuera de PaperTrading - Crypto & Stocks. La moneda virtual no tiene valor monetario en el mundo real y no se puede canjear por moneda fiduciaria u otros activos.'
        ),
        (
          '3. No es asesoramiento financiero y divulgación de la Regla 4.41 de la CFTC',
          'La información, herramientas, modelos algorítmicos y datos de mercado simulados proporcionados por PaperTrading - Crypto & Stocks no constituyen asesoramiento financiero, de inversión, legal o fiscal. PaperTrading - Crypto & Stocks NO es un asesor de inversiones registrado, asesor de negociación de productos básicos ni corredor de bolsa.\n\nAVISO DE LA REGLA 4.41 DE LA CFTC: Los resultados de rendimiento hipotéticos o simulados tienen ciertas limitaciones inherentes. A diferencia de un registro de rendimiento real, los resultados simulados no representan operaciones reales. Además, dado que las operaciones no se han ejecutado realmente, los resultados pueden haber compensado en exceso o en defecto el impacto de ciertos factores del mercado, como la falta de liquidez.'
        ),
        (
          '4. Exactitud de los datos de mercado',
          'PaperTrading - Crypto & Stocks extrae precios de mercado, noticias y otros datos de fuentes públicas de terceros (como Binance y CoinTelegraph). Si bien nos esforzamos por lograr la máxima precisión, no ofrecemos garantías con respecto a la puntualidad, precisión o confiabilidad de estos datos.'
        ),
        (
          '5. Funciones y mecánicas simuladas',
          'Funciones como "Solicitar dinero", "Comprar", "Vender", "Largo", "Corto" y "Liquidaciones" operan estrictamente dentro de los límites del software de simulación. Solicitar dinero al "Admin" simplemente acredita fondos simulados en tu cuenta virtual y no involucra ninguna red bancaria o financiera real.'
        ),
        (
          '6. Advertencias sobre alto apalancamiento y riesgo',
          'PaperTrading - Crypto & Stocks permite experimentar con apalancamiento simulado (hasta 125x) en futuros. Ten en cuenta que el trading real con alto apalancamiento conlleva un riesgo financiero extremo y puede provocar una pérdida total rápida de capital. Las altas tasas de ganancia virtual no garantizan el éxito en intercambios reales.'
        ),
        (
          '7. Centro comunitario y política de tolerancia cero',
          'Al participar en el Centro Comunitario, aceptas nuestro estricto Código de Conducta. PaperTrading - Crypto & Stocks aplica una política de TOLERANCIA CERO contra contenido objetable, incitación al odio, acoso, suplantación de identidad o conducta abusiva. Cualquier usuario que viole estos estándares verá su contenido eliminado de inmediato y su cuenta cancelada permanentemente sin previo aviso.'
        ),
        (
          '8. Campeonatos semanales, Arena y XP',
          'Los torneos, duelos de arena 1v1, tablas de clasificación, puntos XP, rachas e insignias son funciones gamificadas diseñadas para la diversión y el desarrollo de habilidades. Ganar torneos o alcanzar rangos superiores no otorga ningún premio en efectivo ni compensación económica legal.'
        ),
        (
          '9. Limitación de responsabilidad',
          'Bajo ninguna circunstancia los creadores, desarrolladores u operadores de PaperTrading - Crypto & Stocks serán responsables de pérdidas financieras o daños en el mundo real resultantes del uso de este simulador o de la aplicación de estrategias en plataformas reales.'
        ),
        (
          '10. Conducta del usuario e integridad del sistema',
          'Aceptas utilizar PaperTrading - Crypto & Stocks únicamente para sus fines educativos previstos. No debes intentar manipular el motor de simulación, explotar errores para inflar saldos artificialmente ni desplegar bots de scraping automatizados.'
        ),
        (
          '11. Seguridad de la cuenta y derecho de terminación',
          'Eres responsable de mantener seguras tus credenciales de inicio de sesión. Nos reservamos el derecho de suspender, restringir o cancelar cuentas de usuario que violen estos Términos y Condiciones.'
        ),
        (
          '12. Modificaciones a los Términos',
          'Nos reservamos el derecho de actualizar o modificar estos Términos y Condiciones en cualquier momento. El uso continuado de la aplicación tras cualquier actualización constituye la aceptación total de los términos revisados.'
        ),
        (
          '13. Privacidad y protección de datos',
          'Tu privacidad es fundamental para nosotros. Revisa nuestra Política de Privacidad para obtener detalles completos sobre cómo se protegen la información de la cuenta y los datos de simulación.'
        ),
        (
          '14. Marcas comerciales de terceros y propiedad intelectual',
          'Todos los nombres de productos, logotipos y marcas comerciales que se muestran en esta aplicación son propiedad de sus respectivos dueños. La referencia a cualquier producto o servicio de terceros no implica afiliación, respaldo o patrocinio.'
        ),
        (
          '15. Elegibilidad y requisito de edad (18+)',
          'PaperTrading - Crypto & Stocks está destinado exclusivamente a personas mayores de 18 años debido a la presencia de simulación de derivados financieros complejos y funciones comunitarias públicas. Al utilizar esta aplicación, afirmas que cumples con este requisito.'
        ),
      ];
    } else {
      lastUpdatedText = 'Last Updated: Today';
      acceptText = 'By using PaperTrading - Crypto & Stocks, you accept these terms in full.';
      sections = [
        (
          '1. Nature of the Application',
          'PaperTrading - Crypto & Stocks is strictly a paper-trading simulator and educational tool. It is designed to simulate cryptocurrency market mechanics, including spot trading, futures trading, and portfolio management. PaperTrading - Crypto & Stocks is NOT an exchange, brokerage, or financial institution.'
        ),
        (
          '2. Virtual Currency & No Real Money',
          'All funds, balances, rewards, and assets displayed within PaperTrading - Crypto & Stocks are entirely virtual and simulated. You cannot deposit, withdraw, or transfer real money or real cryptocurrencies into or out of PaperTrading - Crypto & Stocks. The virtual currency has zero real-world monetary value and cannot be exchanged for fiat currency or other assets.'
        ),
        (
          '3. Not Financial Advice & CFTC Rule 4.41 Disclosure',
          'The information, tools, algorithmic models, and simulated market data provided by PaperTrading - Crypto & Stocks do not constitute financial, investment, legal, or tax advice. PaperTrading - Crypto & Stocks is NOT a registered investment adviser, commodity trading advisor, or broker.\n\nCFTC RULE 4.41 NOTICE: Hypothetical or simulated performance results have certain inherent limitations. Unlike an actual performance record, simulated results do not represent actual trading. Also, since the trades have not actually been executed, the results may have under- or over-compensated for the impact, if any, of certain market factors, such as lack of liquidity. Simulated trading programs in general are also subject to the fact that they are designed with the benefit of hindsight. No representation is being made that any account will or is likely to achieve profits or losses similar to those shown. Past simulated performance is not indicative of future real-world results.'
        ),
        (
          '4. Market Data Accuracy',
          'PaperTrading - Crypto & Stocks pulls market pricing, news, and other data from third-party public sources (such as Binance and CoinTelegraph). While we strive for accuracy, we make no guarantees regarding the timeliness, precision, or reliability of this data. Delays, inaccuracies, or downtime in third-party feeds may occur.'
        ),
        (
          '5. Simulated Features & Mechanics',
          'Features such as "Request Money", "Buy", "Sell", "Long", "Short", and "Liquidations" operate strictly within the bounds of PaperTrading - Crypto & Stocks\'s simulation software. Requesting money from the "Admin" merely credits your virtual account with simulated funds and does not involve real banking or financial networks.'
        ),
        (
          '6. High Leverage & Risk Warnings',
          'PaperTrading - Crypto & Stocks allows users to experiment with simulated leverage (up to 125x) in Futures Trading. Please be aware that real-world trading with high leverage involves extreme financial risk and can lead to rapid total loss of capital. High virtual win rates in PaperTrading - Crypto & Stocks do not guarantee success in live cryptocurrency exchanges.'
        ),
        (
          '7. Community Hub, User Content & Zero-Tolerance EULA',
          'When participating in the Community Hub (posting setups, commenting, voting, or tipping), you agree to our strict Code of Conduct. PaperTrading - Crypto & Stocks enforces a ZERO-TOLERANCE policy against objectionable content, hate speech, harassment, impersonation, explicit material, fraud, or abusive conduct. Users can report any objectionable content or block abusive users at any time. We moderate all reported items, and any user found violating these standards will have their content removed immediately and their account permanently terminated without prior notice.'
        ),
        (
          '8. Weekly Championships, Arena & XP',
          'Tournaments, 1v1 Arena Duels, leaderboards, XP points, streaks, and badges within PaperTrading - Crypto & Stocks are gamified features designed for fun and skill building. Winning tournaments or achieving top ranks confers no monetary cash prize, real crypto payouts, or legal compensation.'
        ),
        (
          '9. Limitation of Liability',
          'Under no circumstances shall the creators, developers, or operators of PaperTrading - Crypto & Stocks be held liable for any real-world financial losses or damages resulting from the use of this simulator, your reliance on simulated market data, or the application of strategies tested within PaperTrading - Crypto & Stocks to actual real-world trading platforms.'
        ),
        (
          '10. User Conduct & System Integrity',
          'You agree to use PaperTrading - Crypto & Stocks solely for its intended educational purposes. You must not attempt to manipulate the simulation engine, exploit system bugs to artificially inflate virtual balances, deploy automated scraping bots, or reverse engineer PaperTrading - Crypto & Stocks\'s data infrastructure.'
        ),
        (
          '11. Account Security & Right to Terminate',
          'You are responsible for keeping your login credentials secure. We reserve the right to suspend, restrict, or terminate user accounts that violate these Terms & Conditions, engage in toxic behavior in the Community Hub, or disrupt service operation.'
        ),
        (
          '12. Modifications to Terms',
          'We reserve the right to update or modify these Terms & Conditions at any time. Continued use of PaperTrading - Crypto & Stocks following any updates constitutes full acceptance of the revised terms.'
        ),
        (
          '13. Privacy & Data Protection',
          'Your privacy is essential to us. Please review our comprehensive Privacy Policy for full details on how account information, anonymous diagnostic metrics, and simulation states are safeguarded.'
        ),
        (
          '14. Third-Party Trademarks & IP',
          'All product names, logos, trademarks, and registered marks displayed in this application (including Binance, TradingView, CoinTelegraph, and specific cryptocurrency names or ticker symbols) are the property of their respective owners. Reference to any third-party product or service does not constitute or imply affiliation, endorsement, or sponsorship by such parties.'
        ),
        (
          '15. Eligibility & Age Requirement (18+)',
          'PaperTrading - Crypto & Stocks is intended exclusively for individuals aged 18 years or older (or the age of legal majority in your jurisdiction) due to the presence of advanced financial derivatives simulation, leverage mechanics, and public community features. By using this application, you affirm that you meet this age requirement.'
        ),
      ];
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Terms & Conditions'.tr(), style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lastUpdatedText,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            for (final s in sections)
              _buildSection(s.$1, s.$2),
            Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
                },
                icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                label: Text('Read Privacy Policy'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                acceptText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
