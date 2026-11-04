import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final cryptoAssets = [
    'BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'ADAUSDT', 'AVAXUSDT', 'DOTUSDT', 'ATOMUSDT', 'NEARUSDT', 'APTUSDT', 'SUIUSDT', 'ALGOUSDT', 'XLMUSDT', 'TRXUSDT', 'HBARUSDT',
    'MATICUSDT', 'OPUSDT', 'ARBUSDT', 'STXUSDT', 'IMXUSDT',
    'BNBUSDT', 'OKBUSDT', 'CROIUSDT',
    'UNIUSDT', 'AAVEUSDT', 'MKRUSDT', 'CRVUSDT', 'COMPUSDT', 'SNXUSDT', 'LDOUSDT', 'JUPUSDT',
    'LINKUSDT', 'GRTUSDT', 'FILUSDT', 'RENDERUSDT', 'FETUSDT', 'INJUSDT',
    'XRPUSDT', 'LTCUSDT', 'BCHUSDT',
    'SANDUSDT', 'MANAUSDT', 'AXSUSDT', 'GALAUSDT',
    'WLDUSDT', 'TAOUSDT', 'AGIXUSDT',
    'DOGEUSDT', 'SHIBUSDT', 'PEPEUSDT', 'FLOKIUSDT'
  ];
  
  for (var sym in cryptoAssets) {
    try {
      final url = Uri.parse('https://api.binance.com/api/v3/ticker/24hr?symbol=' + sym);
      final res = await http.get(url);
      if (res.statusCode != 200) {
        print('INVALID: ' + sym);
      }
    } catch(e) {}
  }
}
