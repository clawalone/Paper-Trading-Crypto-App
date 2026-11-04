import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CurrencyInfo {
  final String code;
  final String name;
  final String symbol;
  final String flag;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    required this.flag,
  });
}

class CurrencyFormatters {
  static double usdToInr = 84.50; // Legacy & convenience fallback

  /// Real-time exchange rates against USD for 160+ fiat currencies
  static Map<String, double> rates = {
    'USD': 1.0,
    'INR': 84.50,
    'EUR': 0.92,
    'GBP': 0.78,
    'JPY': 155.0,
    'CAD': 1.38,
    'AUD': 1.52,
    'AED': 3.67,
    'SGD': 1.34,
    'CHF': 0.89,
    'SAR': 3.75,
  };

  /// Complete directory of 160+ global fiat currencies
  static const List<CurrencyInfo> allCurrencies = [
    CurrencyInfo(code: 'USD', name: 'United States Dollar', symbol: r'$', flag: '🇺🇸'),
    CurrencyInfo(code: 'INR', name: 'Indian Rupee', symbol: r'₹', flag: '🇮🇳'),
    CurrencyInfo(code: 'EUR', name: 'Euro', symbol: r'€', flag: '🇪🇺'),
    CurrencyInfo(code: 'GBP', name: 'British Pound Sterling', symbol: r'£', flag: '🇬🇧'),
    CurrencyInfo(code: 'JPY', name: 'Japanese Yen', symbol: r'¥', flag: '🇯🇵'),
    CurrencyInfo(code: 'CAD', name: 'Canadian Dollar', symbol: r'CA$', flag: '🇨🇦'),
    CurrencyInfo(code: 'AUD', name: 'Australian Dollar', symbol: r'AU$', flag: '🇦🇺'),
    CurrencyInfo(code: 'AED', name: 'United Arab Emirates Dirham', symbol: r'AED', flag: '🇦🇪'),
    CurrencyInfo(code: 'SGD', name: 'Singapore Dollar', symbol: r'S$', flag: '🇸🇬'),
    CurrencyInfo(code: 'CHF', name: 'Swiss Franc', symbol: r'CHF', flag: '🇨🇭'),
    CurrencyInfo(code: 'SAR', name: 'Saudi Riyal', symbol: r'SAR', flag: '🇸🇦'),
    CurrencyInfo(code: 'HKD', name: 'Hong Kong Dollar', symbol: r'HK$', flag: '🇭🇰'),
    CurrencyInfo(code: 'NZD', name: 'New Zealand Dollar', symbol: r'NZ$', flag: '🇳🇿'),
    CurrencyInfo(code: 'KRW', name: 'South Korean Won', symbol: r'₩', flag: '🇰🇷'),
    CurrencyInfo(code: 'BRL', name: 'Brazilian Real', symbol: r'R$', flag: '🇧🇷'),
    CurrencyInfo(code: 'TRY', name: 'Turkish Lira', symbol: r'₺', flag: '🇹🇷'),
    CurrencyInfo(code: 'RUB', name: 'Russian Ruble', symbol: r'₽', flag: '🇷🇺'),
    CurrencyInfo(code: 'ZAR', name: 'South African Rand', symbol: r'R', flag: '🇿🇦'),
    CurrencyInfo(code: 'MYR', name: 'Malaysian Ringgit', symbol: r'RM', flag: '🇲🇾'),
    CurrencyInfo(code: 'THB', name: 'Thai Baht', symbol: r'฿', flag: '🇹🇭'),
    CurrencyInfo(code: 'AFN', name: 'Afghan Afghani', symbol: r'؋', flag: '🇦🇫'),
    CurrencyInfo(code: 'ALL', name: 'Albanian Lek', symbol: r'L', flag: '🇦🇱'),
    CurrencyInfo(code: 'AMD', name: 'Armenian Dram', symbol: r'֏', flag: '🇦🇲'),
    CurrencyInfo(code: 'ANG', name: 'Netherlands Antillean Guilder', symbol: r'ANG', flag: '🇨🇼'),
    CurrencyInfo(code: 'AOA', name: 'Angolan Kwanza', symbol: r'Kz', flag: '🇦🇴'),
    CurrencyInfo(code: 'ARS', name: 'Argentine Peso', symbol: r'AR$', flag: '🇦🇷'),
    CurrencyInfo(code: 'AWG', name: 'Aruban Florin', symbol: r'AWG', flag: '🇦🇼'),
    CurrencyInfo(code: 'AZN', name: 'Azerbaijani Manat', symbol: r'₼', flag: '🇦🇿'),
    CurrencyInfo(code: 'BAM', name: 'Bosnia-Herzegovina Convertible Mark', symbol: r'KM', flag: '🇧🇦'),
    CurrencyInfo(code: 'BBD', name: 'Barbadian Dollar', symbol: r'Bds$', flag: '🇧🇧'),
    CurrencyInfo(code: 'BDT', name: 'Bangladeshi Taka', symbol: r'৳', flag: '🇧🇩'),
    CurrencyInfo(code: 'BGN', name: 'Bulgarian Lev', symbol: r'лв', flag: '🇧🇬'),
    CurrencyInfo(code: 'BHD', name: 'Bahraini Dinar', symbol: r'BD', flag: '🇧🇭'),
    CurrencyInfo(code: 'BIF', name: 'Burundian Franc', symbol: r'FBu', flag: '🇧🇮'),
    CurrencyInfo(code: 'BMD', name: 'Bermudan Dollar', symbol: r'BD$', flag: '🇧🇲'),
    CurrencyInfo(code: 'BND', name: 'Brunei Dollar', symbol: r'B$', flag: '🇧🇳'),
    CurrencyInfo(code: 'BOB', name: 'Bolivian Boliviano', symbol: r'Bs.', flag: '🇧🇴'),
    CurrencyInfo(code: 'BSD', name: 'Bahamian Dollar', symbol: r'B$', flag: '🇧🇸'),
    CurrencyInfo(code: 'BTN', name: 'Bhutanese Ngultrum', symbol: r'Nu.', flag: '🇧🇹'),
    CurrencyInfo(code: 'BWP', name: 'Botswanan Pula', symbol: r'P', flag: '🇧🇼'),
    CurrencyInfo(code: 'BYN', name: 'Belarusian Ruble', symbol: r'Br', flag: '🇧🇾'),
    CurrencyInfo(code: 'BZD', name: 'Belize Dollar', symbol: r'BZ$', flag: '🇧🇿'),
    CurrencyInfo(code: 'CDF', name: 'Congolese Franc', symbol: r'FC', flag: '🇨🇩'),
    CurrencyInfo(code: 'CLF', name: 'Chilean Unit of Account (UF)', symbol: r'CLF', flag: '🇨🇱'),
    CurrencyInfo(code: 'CLP', name: 'Chilean Peso', symbol: r'CLP$', flag: '🇨🇱'),
    CurrencyInfo(code: 'CNH', name: 'Chinese Yuan (Offshore)', symbol: r'¥', flag: '🇨🇳'),
    CurrencyInfo(code: 'CNY', name: 'Chinese Yuan', symbol: r'¥', flag: '🇨🇳'),
    CurrencyInfo(code: 'COP', name: 'Colombian Peso', symbol: r'COL$', flag: '🇨🇴'),
    CurrencyInfo(code: 'CRC', name: 'Costa Rican Colón', symbol: r'₡', flag: '🇨🇷'),
    CurrencyInfo(code: 'CUP', name: 'Cuban Peso', symbol: r'₱', flag: '🇨🇺'),
    CurrencyInfo(code: 'CVE', name: 'Cape Verdean Escudo', symbol: r'Esc', flag: '🇨🇻'),
    CurrencyInfo(code: 'CZK', name: 'Czech Republic Koruna', symbol: r'Kč', flag: '🇨🇿'),
    CurrencyInfo(code: 'DJF', name: 'Djiboutian Franc', symbol: r'Fdj', flag: '🇩🇯'),
    CurrencyInfo(code: 'DKK', name: 'Danish Krone', symbol: r'kr', flag: '🇩🇰'),
    CurrencyInfo(code: 'DOP', name: 'Dominican Peso', symbol: r'RD$', flag: '🇩🇴'),
    CurrencyInfo(code: 'DZD', name: 'Algerian Dinar', symbol: r'DA', flag: '🇩🇿'),
    CurrencyInfo(code: 'EGP', name: 'Egyptian Pound', symbol: r'E£', flag: '🇪🇬'),
    CurrencyInfo(code: 'ERN', name: 'Eritrean Nakfa', symbol: r'Nfk', flag: '🇪🇷'),
    CurrencyInfo(code: 'ETB', name: 'Ethiopian Birr', symbol: r'Br', flag: '🇪🇹'),
    CurrencyInfo(code: 'FJD', name: 'Fijian Dollar', symbol: r'FJ$', flag: '🇫🇯'),
    CurrencyInfo(code: 'FKP', name: 'Falkland Islands Pound', symbol: r'FK£', flag: '🇫🇰'),
    CurrencyInfo(code: 'FOK', name: 'Faroese Króna', symbol: r'kr', flag: '🇫🇴'),
    CurrencyInfo(code: 'GEL', name: 'Georgian Lari', symbol: r'₾', flag: '🇬🇪'),
    CurrencyInfo(code: 'GGP', name: 'Guernsey Pound', symbol: r'£', flag: '🇬🇬'),
    CurrencyInfo(code: 'GHS', name: 'Ghanaian Cedi', symbol: r'GH₵', flag: '🇬🇭'),
    CurrencyInfo(code: 'GIP', name: 'Gibraltar Pound', symbol: r'£', flag: '🇬🇮'),
    CurrencyInfo(code: 'GMD', name: 'Gambian Dalasi', symbol: r'D', flag: '🇬🇲'),
    CurrencyInfo(code: 'GNF', name: 'Guinean Franc', symbol: r'FG', flag: '🇬🇳'),
    CurrencyInfo(code: 'GTQ', name: 'Guatemalan Quetzal', symbol: r'Q', flag: '🇬🇹'),
    CurrencyInfo(code: 'GYD', name: 'Guyanaese Dollar', symbol: r'G$', flag: '🇬🇾'),
    CurrencyInfo(code: 'HNL', name: 'Honduran Lempira', symbol: r'L', flag: '🇭🇳'),
    CurrencyInfo(code: 'HRK', name: 'Croatian Kuna', symbol: r'kn', flag: '🇭🇷'),
    CurrencyInfo(code: 'HTG', name: 'Haitian Gourde', symbol: r'G', flag: '🇭🇹'),
    CurrencyInfo(code: 'HUF', name: 'Hungarian Forint', symbol: r'Ft', flag: '🇭🇺'),
    CurrencyInfo(code: 'IDR', name: 'Indonesian Rupiah', symbol: r'Rp', flag: '🇮🇩'),
    CurrencyInfo(code: 'ILS', name: 'Israeli New Sheqel', symbol: r'₪', flag: '🇮🇱'),
    CurrencyInfo(code: 'IMP', name: 'Manx pound', symbol: r'£', flag: '🇮🇲'),
    CurrencyInfo(code: 'IQD', name: 'Iraqi Dinar', symbol: r'IQD', flag: '🇮🇶'),
    CurrencyInfo(code: 'IRR', name: 'Iranian Rial', symbol: r'﷼', flag: '🇮🇷'),
    CurrencyInfo(code: 'ISK', name: 'Icelandic Króna', symbol: r'kr', flag: '🇮🇸'),
    CurrencyInfo(code: 'JEP', name: 'Jersey Pound', symbol: r'£', flag: '🇯🇪'),
    CurrencyInfo(code: 'JMD', name: 'Jamaican Dollar', symbol: r'J$', flag: '🇯🇲'),
    CurrencyInfo(code: 'JOD', name: 'Jordanian Dinar', symbol: r'JOD', flag: '🇯🇴'),
    CurrencyInfo(code: 'KES', name: 'Kenyan Shilling', symbol: r'KSh', flag: '🇰🇪'),
    CurrencyInfo(code: 'KGS', name: 'Kyrgystani Som', symbol: r'с', flag: '🇰🇬'),
    CurrencyInfo(code: 'KHR', name: 'Cambodian Riel', symbol: r'៛', flag: '🇰🇭'),
    CurrencyInfo(code: 'KID', name: 'Kiribati Dollar', symbol: r'$', flag: '🇰🇮'),
    CurrencyInfo(code: 'KMF', name: 'Comorian Franc', symbol: r'CF', flag: '🇰🇲'),
    CurrencyInfo(code: 'KWD', name: 'Kuwaiti Dinar', symbol: r'KD', flag: '🇰🇼'),
    CurrencyInfo(code: 'KYD', name: 'Cayman Islands Dollar', symbol: r'CI$', flag: '🇰🇾'),
    CurrencyInfo(code: 'KZT', name: 'Kazakhstani Tenge', symbol: r'₸', flag: '🇰🇿'),
    CurrencyInfo(code: 'LAK', name: 'Laotian Kip', symbol: r'₭', flag: '🇱🇦'),
    CurrencyInfo(code: 'LBP', name: 'Lebanese Pound', symbol: r'L£', flag: '🇱🇧'),
    CurrencyInfo(code: 'LKR', name: 'Sri Lankan Rupee', symbol: r'Rs', flag: '🇱🇰'),
    CurrencyInfo(code: 'LRD', name: 'Liberian Dollar', symbol: r'L$', flag: '🇱🇷'),
    CurrencyInfo(code: 'LSL', name: 'Lesotho Loti', symbol: r'M', flag: '🇱🇸'),
    CurrencyInfo(code: 'LYD', name: 'Libyan Dinar', symbol: r'LD', flag: '🇱🇾'),
    CurrencyInfo(code: 'MAD', name: 'Moroccan Dirham', symbol: r'MAD', flag: '🇲🇦'),
    CurrencyInfo(code: 'MDL', name: 'Moldovan Leu', symbol: r'L', flag: '🇲🇩'),
    CurrencyInfo(code: 'MGA', name: 'Malagasy Ariary', symbol: r'Ar', flag: '🇲🇬'),
    CurrencyInfo(code: 'MKD', name: 'Macedonian Denar', symbol: r'ден', flag: '🇲🇰'),
    CurrencyInfo(code: 'MMK', name: 'Myanma Kyat', symbol: r'K', flag: '🇲🇲'),
    CurrencyInfo(code: 'MNT', name: 'Mongolian Tugrik', symbol: r'₮', flag: '🇲🇳'),
    CurrencyInfo(code: 'MOP', name: 'Macanese Pataca', symbol: r'MOP$', flag: '🇲🇴'),
    CurrencyInfo(code: 'MRU', name: 'Mauritanian Ouguiya', symbol: r'UM', flag: '🇲🇷'),
    CurrencyInfo(code: 'MUR', name: 'Mauritian Rupee', symbol: r'₨', flag: '🇲🇺'),
    CurrencyInfo(code: 'MVR', name: 'Maldivian Rufiyaa', symbol: r'Rf', flag: '🇲🇻'),
    CurrencyInfo(code: 'MWK', name: 'Malawian Kwacha', symbol: r'MK', flag: '🇲🇼'),
    CurrencyInfo(code: 'MXN', name: 'Mexican Peso', symbol: r'MX$', flag: '🇲🇽'),
    CurrencyInfo(code: 'MZN', name: 'Mozambican Metical', symbol: r'MT', flag: '🇲🇿'),
    CurrencyInfo(code: 'NAD', name: 'Namibian Dollar', symbol: r'N$', flag: '🇳🇦'),
    CurrencyInfo(code: 'NGN', name: 'Nigerian Naira', symbol: r'₦', flag: '🇳🇬'),
    CurrencyInfo(code: 'NIO', name: 'Nicaraguan Córdoba', symbol: r'C$', flag: '🇳🇮'),
    CurrencyInfo(code: 'NOK', name: 'Norwegian Krone', symbol: r'kr', flag: '🇳🇴'),
    CurrencyInfo(code: 'NPR', name: 'Nepalese Rupee', symbol: r'Rs', flag: '🇳🇵'),
    CurrencyInfo(code: 'OMR', name: 'Omani Rial', symbol: r'OMR', flag: '🇴🇲'),
    CurrencyInfo(code: 'PAB', name: 'Panamanian Balboa', symbol: r'B/.', flag: '🇵🇦'),
    CurrencyInfo(code: 'PEN', name: 'Peruvian Nuevo Sol', symbol: r'S/', flag: '🇵🇪'),
    CurrencyInfo(code: 'PGK', name: 'Papua New Guinean Kina', symbol: r'K', flag: '🇵🇬'),
    CurrencyInfo(code: 'PHP', name: 'Philippine Peso', symbol: r'₱', flag: '🇵🇭'),
    CurrencyInfo(code: 'PKR', name: 'Pakistani Rupee', symbol: r'₨', flag: '🇵🇰'),
    CurrencyInfo(code: 'PLN', name: 'Polish Zloty', symbol: r'zł', flag: '🇵🇱'),
    CurrencyInfo(code: 'PYG', name: 'Paraguayan Guarani', symbol: r'₲', flag: '🇵🇾'),
    CurrencyInfo(code: 'QAR', name: 'Qatari Rial', symbol: r'QR', flag: '🇶🇦'),
    CurrencyInfo(code: 'RON', name: 'Romanian Leu', symbol: r'lei', flag: '🇷🇴'),
    CurrencyInfo(code: 'RSD', name: 'Serbian Dinar', symbol: r'дин', flag: '🇷🇸'),
    CurrencyInfo(code: 'RWF', name: 'Rwandan Franc', symbol: r'FRw', flag: '🇷🇼'),
    CurrencyInfo(code: 'SBD', name: 'Solomon Islands Dollar', symbol: r'SI$', flag: '🇸🇧'),
    CurrencyInfo(code: 'SCR', name: 'Seychellois Rupee', symbol: r'SR', flag: '🇸🇨'),
    CurrencyInfo(code: 'SDG', name: 'Sudanese Pound', symbol: r'SDG', flag: '🇸🇩'),
    CurrencyInfo(code: 'SEK', name: 'Swedish Krona', symbol: r'kr', flag: '🇸🇪'),
    CurrencyInfo(code: 'SHP', name: 'Saint Helena Pound', symbol: r'£', flag: '🇸🇭'),
    CurrencyInfo(code: 'SLE', name: 'Sierra Leonean Leone', symbol: r'Le', flag: '🇸🇱'),
    CurrencyInfo(code: 'SLL', name: 'Sierra Leonean Leone (Old)', symbol: r'Le', flag: '🇸🇱'),
    CurrencyInfo(code: 'SOS', name: 'Somali Shilling', symbol: r'Sh', flag: '🇸🇴'),
    CurrencyInfo(code: 'SRD', name: 'Surinamese Dollar', symbol: r'Sr$', flag: '🇸🇷'),
    CurrencyInfo(code: 'SSP', name: 'South Sudanese Pound', symbol: r'£', flag: '🇸🇸'),
    CurrencyInfo(code: 'STN', name: 'São Tomé and Príncipe Dobra', symbol: r'Db', flag: '🇸🇹'),
    CurrencyInfo(code: 'SYP', name: 'Syrian Pound', symbol: r'S£', flag: '🇸🇾'),
    CurrencyInfo(code: 'SZL', name: 'Swazi Lilangeni', symbol: r'E', flag: '🇸🇿'),
    CurrencyInfo(code: 'TJS', name: 'Tajikistani Somoni', symbol: r'SM', flag: '🇹🇯'),
    CurrencyInfo(code: 'TMT', name: 'Turkmenistani Manat', symbol: r'T', flag: '🇹🇲'),
    CurrencyInfo(code: 'TND', name: 'Tunisian Dinar', symbol: r'DT', flag: '🇹🇳'),
    CurrencyInfo(code: 'TOP', name: 'Tongan Pa\'anga', symbol: r'T$', flag: '🇹🇴'),
    CurrencyInfo(code: 'TTD', name: 'Trinidad and Tobago Dollar', symbol: r'TT$', flag: '🇹🇹'),
    CurrencyInfo(code: 'TVD', name: 'Tuvaluan Dollar', symbol: r'$', flag: '🇹🇻'),
    CurrencyInfo(code: 'TWD', name: 'New Taiwan Dollar', symbol: r'NT$', flag: '🇹🇼'),
    CurrencyInfo(code: 'TZS', name: 'Tanzanian Shilling', symbol: r'TSh', flag: '🇹🇿'),
    CurrencyInfo(code: 'UAH', name: 'Ukrainian Hryvnia', symbol: r'₴', flag: '🇺🇦'),
    CurrencyInfo(code: 'UGX', name: 'Ugandan Shilling', symbol: r'USh', flag: '🇺🇬'),
    CurrencyInfo(code: 'UYU', name: 'Uruguayan Peso', symbol: r'$U', flag: '🇺🇾'),
    CurrencyInfo(code: 'UZS', name: 'Uzbekistan Som', symbol: r'soʻm', flag: '🇺🇿'),
    CurrencyInfo(code: 'VES', name: 'Venezuelan Bolívar Soberano', symbol: r'Bs.S', flag: '🇻🇪'),
    CurrencyInfo(code: 'VND', name: 'Vietnamese Dong', symbol: r'₫', flag: '🇻🇳'),
    CurrencyInfo(code: 'VUV', name: 'Vanuatu Vatu', symbol: r'VT', flag: '🇻🇺'),
    CurrencyInfo(code: 'WST', name: 'Samoan Tala', symbol: r'WS$', flag: '🇼🇸'),
    CurrencyInfo(code: 'XAF', name: 'CFA Franc BEAC', symbol: r'FCFA', flag: '🇨🇲'),
    CurrencyInfo(code: 'XCD', name: 'East Caribbean Dollar', symbol: r'EC$', flag: '🇦🇬'),
    CurrencyInfo(code: 'XCG', name: 'Caribbean Guilder', symbol: r'XCG', flag: '🇨🇼'),
    CurrencyInfo(code: 'XDR', name: 'Special Drawing Rights', symbol: r'XDR', flag: '🌐'),
    CurrencyInfo(code: 'XOF', name: 'CFA Franc BCEAO', symbol: r'CFA', flag: '🇸🇳'),
    CurrencyInfo(code: 'XPF', name: 'CFP Franc', symbol: r'CFPF', flag: '🇵🇫'),
    CurrencyInfo(code: 'YER', name: 'Yemeni Rial', symbol: r'YR', flag: '🇾🇪'),
    CurrencyInfo(code: 'ZMW', name: 'Zambian Kwacha', symbol: r'ZK', flag: '🇿🇲'),
    CurrencyInfo(code: 'ZWG', name: 'Zimbabwean ZiG', symbol: r'ZWG', flag: '🇿🇼'),
    CurrencyInfo(code: 'ZWL', name: 'Zimbabwean Dollar', symbol: r'Z$', flag: '🇿🇼'),
  ];

  static final Map<String, CurrencyInfo> currencyMap = {
    for (final c in allCurrencies) c.code: c,
  };

  static CurrencyInfo getInfo(String? currencyCode) {
    if (currencyCode == null || currencyCode.isEmpty) {
      return currencyMap['USD'] ?? const CurrencyInfo(code: 'USD', name: 'United States Dollar', symbol: r'$', flag: '🇺🇸');
    }
    return currencyMap[currencyCode] ?? CurrencyInfo(
      code: currencyCode,
      name: currencyCode,
      symbol: currencyCode,
      flag: '🌐',
    );
  }

  /// Fetches live exchange rates for all 160+ fiat currencies
  static Future<void> initExchangeRate() async {
    try {
      final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/USD')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['rates'] != null && data['rates'] is Map) {
          final rawRates = data['rates'] as Map<String, dynamic>;
          rates = rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
          if (rates.containsKey('INR')) {
            usdToInr = rates['INR']!;
          }
        }
      }
    } catch (_) {
      // Fallback to default rates if offline or API error
    }
  }

  /// Returns the currency symbol (e.g., $, ₹, €, £, ¥)
  static String getSymbol(String? currencyCode) {
    return getInfo(currencyCode).symbol;
  }

  /// Converts an amount in USD to the target currency amount
  static double convertUsd(double amountUsd, String? currencyCode) {
    final target = (currencyCode == null || currencyCode.isEmpty) ? 'USD' : currencyCode;
    final inrRate = rates['INR'] ?? usdToInr;
    final targetRate = rates[target] ?? (target == 'USD' ? 1.0 : (target == 'INR' ? inrRate : 1.0));
    return amountUsd * targetRate;
  }

  /// Converts and formats an amount in USD to the target currency
  static String formatUsd(double amountUsd, String? currencyCode, {int decimalDigits = 2}) {
    final code = currencyCode ?? 'USD';
    final amount = convertUsd(amountUsd, code);
    final symbol = getSymbol(code);
    final digits = (code == 'JPY' || code == 'KRW' || code == 'VND' || code == 'IDR') ? 0 : decimalDigits;

    final formatter = NumberFormat.currency(
      locale: _getLocale(code),
      symbol: symbol,
      decimalDigits: digits,
    );
    return formatter.format(amount);
  }

  /// Converts a base INR amount to the target currency amount
  static double convert(double baseAmountInr, String? currencyCode) {
    final target = (currencyCode == null || currencyCode.isEmpty) ? 'USD' : currencyCode;
    final inrRate = rates['INR'] ?? usdToInr;
    final targetRate = rates[target] ?? (target == 'USD' ? 1.0 : (target == 'INR' ? inrRate : 1.0));
    if (inrRate <= 0) return baseAmountInr;
    return (baseAmountInr / inrRate) * targetRate;
  }

  /// Converts and formats a base INR amount to the target currency
  static String format(double baseAmountInr, String? currencyCode, {int decimalDigits = 2}) {
    final code = currencyCode ?? 'USD';
    final amount = convert(baseAmountInr, code);
    final symbol = getSymbol(code);
    final digits = (code == 'JPY' || code == 'KRW' || code == 'VND' || code == 'IDR') ? 0 : decimalDigits;

    final formatter = NumberFormat.currency(
      locale: _getLocale(code),
      symbol: symbol,
      decimalDigits: digits,
    );
    return formatter.format(amount);
  }

  /// Converts and formats a base INR amount in compact form (e.g., $1.2K, €1.2M)
  static String formatCompact(double baseAmountInr, String? currencyCode) {
    final code = currencyCode ?? 'USD';
    final amount = convert(baseAmountInr, code);
    final symbol = getSymbol(code);

    final formatter = NumberFormat.compactCurrency(
      locale: _getLocale(code),
      symbol: symbol,
    );
    return formatter.format(amount);
  }

  /// Returns a full currency formatter
  static NumberFormat getFormatter(String? currencyCode, {int decimalDigits = 2}) {
    final code = currencyCode ?? 'USD';
    final symbol = getSymbol(code);
    final digits = (code == 'JPY' || code == 'KRW' || code == 'VND' || code == 'IDR') ? 0 : decimalDigits;
    return NumberFormat.currency(
      locale: _getLocale(code),
      symbol: symbol,
      decimalDigits: digits,
    );
  }

  /// Returns a compact currency formatter
  static NumberFormat getCompactFormatter(String? currencyCode) {
    final code = currencyCode ?? 'USD';
    final symbol = getSymbol(code);
    return NumberFormat.compactCurrency(
      locale: _getLocale(code),
      symbol: symbol,
    );
  }

  static String _getLocale(String code) {
    switch (code) {
      case 'INR': return 'en_IN';
      case 'EUR': return 'en_IE';
      case 'GBP': return 'en_GB';
      case 'JPY': return 'ja_JP';
      case 'CAD': return 'en_CA';
      case 'AUD': return 'en_AU';
      case 'CNY': return 'zh_CN';
      default: return 'en_US';
    }
  }
}

class AppCurrencyFormatter {
  final String? currencyCode;
  final int decimalDigits;

  AppCurrencyFormatter(this.currencyCode, {this.decimalDigits = 2});

  String format(num? baseAmountInr) {
    final val = (baseAmountInr ?? 0).toDouble();
    return CurrencyFormatters.format(val, currencyCode, decimalDigits: decimalDigits);
  }
}

class AppCompactCurrencyFormatter {
  final String? currencyCode;

  AppCompactCurrencyFormatter(this.currencyCode);

  String format(num? baseAmountInr) {
    final val = (baseAmountInr ?? 0).toDouble();
    return CurrencyFormatters.formatCompact(val, currencyCode);
  }
}
