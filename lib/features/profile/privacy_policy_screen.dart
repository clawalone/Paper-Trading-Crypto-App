import 'package:stock_arena/core/app_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../data/user_provider.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _openWebPolicy() async {
    final uri = Uri.parse('https://studio-9401559078-23caf.web.app/privacy.html');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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

    final String bannerTitle;
    final String bannerDesc;
    final String lastUpdatedText;
    final List<(String, String)> sections;

    if (lang == 'hi') {
      bannerTitle = '100% वर्चुअल सिम्युलेटर — कोई वित्तीय जोखिम नहीं';
      bannerDesc = 'PaperTrading - Crypto & Stocks पूरी तरह से एक शैक्षिक उपकरण है। हम वास्तविक जमा, वास्तविक मुद्रा या वास्तविक क्रिप्टो परिसंपत्तियों का प्रबंधन नहीं करते हैं।';
      lastUpdatedText = 'अंतिम अपडेट: 6 नवंबर, 2026';
      sections = [
        (
          '1. अवलोकन और दायरा',
          'यह गोपनीयता नीति बताती है कि जब आप हमारे मोबाइल एप्लिकेशन PaperTrading - Crypto & Stocks (com.acadriotrade) का उपयोग करते हैं तो Acadrio ("हम", "हमारा") जानकारी कैसे एकत्र, उपयोग और सुरक्षित करता है। हम GDPR (EU), CCPA/CPRA (कैलिफ़ोर्निया) और Google Play डेवलपर नीतियों सहित वैश्विक गोपनीयता नियमों के तहत आपकी गोपनीयता की रक्षा करने और पारदर्शी डेटा प्रथाओं को सुनिश्चित करने के लिए समर्पित हैं।'
        ),
        (
          '2. हम कौन सी जानकारी एकत्र करते हैं',
          '• खाता जानकारी: जब आप Firebase प्रमाणीकरण के माध्यम से एक खाता बनाते हैं, तो हम आपका चुना हुआ ट्रेडर नाम, चयनित एनिमेटेड अवतार और खाता पहचानकर्ता संग्रहीत करते हैं। हम इस जानकारी को कभी बेचते या किराए पर नहीं देते हैं।\n\n'
          '• सिमुलेशन गतिविधि: हम सत्रों में आपके सिम्युलेटर की स्थिति को सिंक्रनाइज़ करने के लिए आपके वर्चुअल पोर्टफोलियो बैलेंस, पेपर ट्रेड इतिहास (स्पॉट/फ्यूचर्स ऑर्डर), टूर्नामेंट स्कोर और XP मील के पत्थर रिकॉर्ड करते हैं।\n\n'
          '• डिवाइस और डायग्नोस्टिक मेट्रिक्स: प्लेटफॉर्म स्थिरता की निगरानी और बग को ठीक करने के लिए Google Firebase के माध्यम से अनाम डिवाइस पहचानकर्ता, क्रैश लॉग और ऑपरेटिंग सिस्टम डायग्नोस्टिक्स एकत्र किए जाते हैं।\n\n'
          '• पुश नोटिफिकेशन टोकन: स्वैच्छिक Firebase क्लाउड मैसेजिंग (FCM) टोकन मूल्य अलर्ट, ट्रेड सेटलमेंट सूचनाएं और टूर्नामेंट अपडेट प्रदान करते हैं।'
        ),
        (
          '3. हम जानकारी का उपयोग कैसे करते हैं',
          'हम विशेष रूप से वैध परिचालन आवश्यकताओं के लिए डेटा संसाधित करते हैं:\n'
          '• आपके सिम्युलेटर पोर्टफोलियो और लॉगिन स्थिति का प्रबंधन करना।\n'
          '• लीडरबोर्ड स्टैंडिंग और साप्ताहिक चैंपियनशिप परिणामों की गणना करना।\n'
          '• वर्चुअल पूंजी रीफिल के लिए स्वैच्छिक पुरस्कृत विज्ञापनों के पूरा होने का सत्यापन करना।\n'
          '• प्लेटफ़ॉर्म अखंडता बनाए रखना और स्वचालित बॉट हेरफेर को रोकना।'
        ),
        (
          '4. इन-ऐप खरीदारी (Google Play बिलिंग)',
          'सभी टॉप-अप पैकेज विशेष रूप से Google Play इन-ऐप बिलिंग के माध्यम से संसाधित किए जाते हैं। हम कभी भी आपके क्रेडिट कार्ड, डेबिट कार्ड या बैंकिंग विवरण प्राप्त, संसाधित या संग्रहीत नहीं करते हैं। सभी खरीदारी शून्य वास्तविक नकदी समतुल्यता के साथ वर्चुअल, गैर-निकासी योग्य सिमुलेशन पूंजी प्रदान करती हैं।'
        ),
        (
          '5. विज्ञापन और यूरोपीय सहमति (GDPR / UMP)',
          'हम स्वैच्छिक पुरस्कृत वीडियो विज्ञापनों के लिए Google AdMob का उपयोग करते हैं। यूरोपीय आर्थिक क्षेत्र (EEA), यूके और स्विट्जरलैंड के उपयोगकर्ताओं के लिए, हम वैयक्तिकृत विज्ञापन दिखाने से पहले स्पष्ट सहमति प्राप्त करने के लिए Google के प्रमाणित उपयोगकर्ता मैसेजिंग प्लेटफ़ॉर्म (UMP) का उपयोग करते हैं।'
        ),
        (
          '6. उपयोगकर्ता सामग्री और मॉडरेशन',
          'हमारा कम्युनिटी हब व्यापारियों को सिमुलेटेड ट्रेड पोस्ट और टिप्पणियां साझा करने की अनुमति देता है। हम अभद्र भाषा, उत्पीड़न, स्पैम, घोटाले या अवैध सामग्री के लिए शून्य सहनशीलता बनाए रखते हैं। उपयोगकर्ता सीधे ऐप के भीतर अनुचित पोस्ट की रिपोर्ट कर सकते हैं और अपमानजनक व्यापारियों को ब्लॉक कर सकते हैं।'
        ),
        (
          '7. खाता और डेटा हटाने के अधिकार',
          'आपको किसी भी समय अपने खाते और संबंधित व्यक्तिगत डेटा को स्थायी रूप से हटाने का पूर्ण अधिकार है:\n'
          '• ऐप में: प्रोफ़ाइल स्क्रीन → खाता हटाएं (आपके खाते और प्रोफ़ाइल डेटा को स्थायी रूप से हटा देता है)।\n'
          '• वेब पोर्टल: https://studio-9401559078-23caf.web.app/delete-account.html\n'
          '• ईमेल अनुरोध: acadrio.query@gmail.com पर हमसे संपर्क करें।'
        ),
        (
          '8. बच्चों की गोपनीयता',
          'जटिल सिमुलेटेड वित्तीय डेरिवेटिव और लीवरेज मैकेनिक्स के कारण PaperTrading - Crypto & Stocks 18 वर्ष और उससे अधिक आयु के दर्शकों के लिए अभिप्रेत है। हम जानबूझकर 13 वर्ष से कम उम्र के व्यक्तियों से व्यक्तिगत जानकारी एकत्र नहीं करते हैं।'
        ),
        (
          '9. संपर्क और पूछताछ',
          'यदि इस गोपनीयता नीति के संबंध में आपके कोई प्रश्न या डेटा गोपनीयता अनुरोध हैं, तो कृपया हमारी डेटा सुरक्षा टीम को acadrio.query@gmail.com पर ईमेल करें।'
        ),
      ];
    } else if (lang == 'es') {
      bannerTitle = 'Simulador 100% virtual — Sin riesgo financiero real';
      bannerDesc = 'PaperTrading - Crypto & Stocks es estrictamente una herramienta educativa. No gestionamos depósitos reales, monedas fiduciarias ni criptoactivos reales.';
      lastUpdatedText = 'Última actualización: 6 de noviembre de 2026';
      sections = [
        (
          '1. Descripción general y alcance',
          'Esta Política de Privacidad explica cómo Acadrio ("nosotros", "nuestro") recopila, utiliza y protege la información cuando utilizas nuestra aplicación móvil PaperTrading - Crypto & Stocks (com.acadriotrade). Nos dedicamos a proteger tu privacidad y garantizar prácticas de datos transparentes bajo las regulaciones globales de privacidad, incluidas el RGPD (UE), CCPA/CPRA (California) y las Políticas para Desarrolladores de Google Play.'
        ),
        (
          '2. Información que recopilamos',
          '• Información de la cuenta: cuando creas una cuenta a través de Firebase Authentication, almacenamos el nombre de usuario de trader elegido, el avatar animado seleccionado y el identificador de la cuenta. No vendemos ni alquilamos esta información.\n\n'
          '• Actividad de simulación: registramos el saldo de tu portafolio virtual, el historial de operaciones simuladas (órdenes spot/futuros), la puntuación del torneo y los hitos de XP para sincronizar el estado de tu simulador en todas las sesiones.\n\n'
          '• Métricas del dispositivo y diagnóstico: se recopilan identificadores de dispositivo anónimos, registros de fallos y diagnósticos del sistema operativo a través de Google Firebase para monitorear la estabilidad de la plataforma y corregir errores.\n\n'
          '• Tokens de notificaciones push: los tokens voluntarios de Firebase Cloud Messaging (FCM) envían alertas de precios opcionales, notificaciones de liquidación de operaciones y actualizaciones de torneos.'
        ),
        (
          '3. Cómo utilizamos la información',
          'Procesamos los datos exclusivamente para necesidades operativas legítimas:\n'
          '• Gestionar el portafolio de tu simulador y el estado de inicio de sesión.\n'
          '• Calcular la clasificación del torneo y los resultados de los campeonatos semanales.\n'
          '• Verificar la finalización de anuncios recompensados voluntarios para recargas de capital virtual.\n'
          '• Mantener la integridad de la plataforma y evitar la manipulación automatizada mediante bots.'
        ),
        (
          '4. Compras en la aplicación (Google Play Billing)',
          'Todos los paquetes de recarga se procesan exclusivamente a través de Google Play In-App Billing. Nunca recibimos, procesamos ni almacenamos los datos de tus tarjetas de crédito o cuentas bancarias. Todas las compras otorgan capital de simulación virtual, no retirable y sin equivalencia con dinero real.'
        ),
        (
          '5. Publicidad y consentimiento europeo (RGPD / UMP)',
          'Utilizamos Google AdMob para anuncios de vídeo recompensados voluntarios. Para los usuarios en el Espacio Económico Europeo (EEE), el Reino Unido y Suiza, utilizamos la Plataforma de Mensajería de Usuario (UMP) certificada de Google para obtener el consentimiento explícito antes de publicar anuncios personalizados.'
        ),
        (
          '6. Contenido del usuario y moderación',
          'Nuestro Centro Comunitario permite a los traders compartir publicaciones y comentarios. Mantenemos una política de tolerancia cero ante discursos de odio, acoso, spam o contenido ilegal. Los usuarios pueden denunciar publicaciones inapropiadas y bloquear traders abusivos directamente en la app.'
        ),
        (
          '7. Derechos de eliminación de cuenta y datos',
          'Tienes el derecho absoluto de eliminar tu cuenta y los datos personales asociados en cualquier momento:\n'
          '• En la app: Pantalla de perfil → Eliminar cuenta (elimina permanentemente tu cuenta y datos de perfil).\n'
          '• Portal web: https://studio-9401559078-23caf.web.app/delete-account.html\n'
          '• Solicitud por correo electrónico: Contáctanos en acadrio.query@gmail.com.'
        ),
        (
          '8. Privacidad infantil',
          'PaperTrading - Crypto & Stocks está destinado a personas mayores de 18 años debido a la simulación de derivados financieros complejos y mecanismos de apalancamiento. No recopilamos a sabiendas información personal de menores de 13 años.'
        ),
        (
          '9. Contacto y consultas',
          'Si tienes alguna pregunta o solicitud de privacidad de datos sobre esta Política de Privacidad, envía un correo electrónico a nuestro Equipo de Protección de Datos a acadrio.query@gmail.com.'
        ),
      ];
    } else {
      bannerTitle = '100% Virtual Simulator — No Real Financial Risk';
      bannerDesc = 'PaperTrading - Crypto & Stocks is strictly an educational tool. We do not manage real deposits, fiat currencies, or real crypto assets.';
      lastUpdatedText = 'Last Updated: November 6, 2026';
      sections = [
        (
          '1. Overview & Scope',
          'This Privacy Policy explains how Acadrio ("we", "our", or "us") collects, uses, and safeguards information when you use our mobile application PaperTrading - Crypto & Stocks (com.acadriotrade). We are dedicated to protecting your privacy and ensuring transparent data practices under global privacy regulations including the GDPR (EU), CCPA/CPRA (California), and Google Play Developer Policies.'
        ),
        (
          '2. Information We Collect',
          '• Account Information: When you create an account via Firebase Authentication, we store your chosen trader display name, selected animated avatar, and account identifier. We do not sell or rent this information.\n\n'
          '• Simulation Activity: We record your virtual portfolio balance, paper trade history (spot/futures orders), tournament score, and XP milestones to synchronize your simulator state across sessions.\n\n'
          '• Device & Diagnostic Metrics: Anonymous device identifiers, crash logs, and operating system diagnostics are collected via Google Firebase to monitor platform stability and fix bugs.\n\n'
          '• Push Notification Tokens: Voluntary Firebase Cloud Messaging (FCM) tokens deliver opt-in price alerts, trade settlement notifications, and tournament updates.'
        ),
        (
          '3. How We Use Information',
          'We process data exclusively for legitimate operational needs:\n'
          '• Managing your simulator portfolio and login state.\n'
          '• Calculating leaderboard standings and weekly championship results.\n'
          '• Verifying completion of voluntary rewarded ads for virtual capital refills.\n'
          '• Maintaining platform integrity and preventing automated bot manipulation.'
        ),
        (
          '4. In-App Purchases (Google Play Billing)',
          'All top-up packages are processed exclusively through Google Play In-App Billing. We never receive, process, or store your credit card, debit card, or banking details. All purchases grant virtual, non-withdrawable simulation capital with zero real-world cash equivalence.'
        ),
        (
          '5. Advertising & European Consent (GDPR / UMP)',
          'We use Google AdMob for voluntary rewarded video ads. For users in the European Economic Area (EEA), the UK, and Switzerland, we utilize Google’s certified User Messaging Platform (UMP) to obtain explicit consent before serving personalized advertisements.'
        ),
        (
          '6. User Content & Moderation',
          'Our Community Hub allows traders to share simulated trade posts and comments. We maintain zero tolerance for hate speech, harassment, spam, scams, or illegal material. Users can report inappropriate posts and block abusive traders directly within the app.'
        ),
        (
          '7. Account & Data Deletion Rights',
          'You have the absolute right to delete your account and associated personal data at any time:\n'
          '• In-App: Profile Screen → Delete Account (permanently removes your account and profile data).\n'
          '• Web Portal: https://studio-9401559078-23caf.web.app/delete-account.html\n'
          '• Email Request: Contact us at acadrio.query@gmail.com.'
        ),
        (
          '8. Children’s Privacy',
          'PaperTrading - Crypto & Stocks is intended for audiences aged 18 and older due to complex simulated financial derivatives and leverage mechanics. We do not knowingly collect personal information from individuals under the age of 13 (or under 16 in the European Union).'
        ),
        (
          '9. Contact & Inquiries',
          'If you have any questions or data privacy requests regarding this Privacy Policy, please email our Data Protection Team at acadrio.query@gmail.com.'
        ),
      ];
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Privacy Policy'.tr(), style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.profit.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.profit.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.profit, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bannerTitle,
                          style: const TextStyle(color: AppColors.profit, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bannerDesc,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              lastUpdatedText,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),

            for (final s in sections)
              _buildSection(s.$1, s.$2),

            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                onPressed: _openWebPolicy,
                icon: const Icon(Icons.language_rounded, size: 16),
                label: Text('View Full Policy on Web (https://studio-9401559078-23caf.web.app)'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
