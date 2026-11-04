import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/currency_formatters.dart';

class OrderBookEntry {
  final double price; // Base currency (INR)
  final double rawPrice; // Binance USD price
  final double qty;
  final double total;

  const OrderBookEntry({
    required this.price,
    required this.rawPrice,
    required this.qty,
    this.total = 0.0,
  });

  @override
  String toString() => 'OrderBookEntry(price: $price, qty: $qty)';
}

class OrderBookState {
  final List<OrderBookEntry> bids;
  final List<OrderBookEntry> asks;
  final double maxQty;
  final bool isLoading;
  final bool isLive;
  final String? error;
  final DateTime? lastUpdated;

  const OrderBookState({
    this.bids = const [],
    this.asks = const [],
    this.maxQty = 1.0,
    this.isLoading = true,
    this.isLive = false,
    this.error,
    this.lastUpdated,
  });

  OrderBookState copyWith({
    List<OrderBookEntry>? bids,
    List<OrderBookEntry>? asks,
    double? maxQty,
    bool? isLoading,
    bool? isLive,
    String? error,
    DateTime? lastUpdated,
  }) {
    return OrderBookState(
      bids: bids ?? this.bids,
      asks: asks ?? this.asks,
      maxQty: maxQty ?? this.maxQty,
      isLoading: isLoading ?? this.isLoading,
      isLive: isLive ?? this.isLive,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class OrderBookParams {
  final String symbol;
  final bool isFutures;

  const OrderBookParams({
    required this.symbol,
    this.isFutures = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderBookParams &&
          runtimeType == other.runtimeType &&
          symbol.toUpperCase() == other.symbol.toUpperCase() &&
          isFutures == other.isFutures;

  @override
  int get hashCode => symbol.toUpperCase().hashCode ^ isFutures.hashCode;
}

final orderBookProvider = StreamProvider.autoDispose
    .family<OrderBookState, OrderBookParams>((ref, params) {
  final rawSym = params.symbol.toUpperCase().replaceAll('USDT', '');
  final pair = '${rawSym}USDT';
  final isFutures = params.isFutures;

  final controller = StreamController<OrderBookState>();
  WebSocketChannel? channel;
  Timer? throttleTimer;
  Timer? reconnectTimer;
  OrderBookState? pendingState;
  OrderBookState currentState = const OrderBookState(isLoading: true);
  bool isDisposed = false;

  void emitState(OrderBookState newState) {
    if (isDisposed || controller.isClosed) return;
    currentState = newState;
    controller.add(newState);
  }

  List<OrderBookEntry> parseEntries(dynamic list, double fxRate) {
    if (list is! List) return const [];
    final entries = <OrderBookEntry>[];
    double runningTotal = 0.0;

    for (final item in list) {
      if (item is List && item.length >= 2) {
        final rawP = double.tryParse(item[0].toString()) ?? 0.0;
        final q = double.tryParse(item[1].toString()) ?? 0.0;
        if (rawP > 0 && q > 0) {
          runningTotal += q;
          entries.add(OrderBookEntry(
            price: rawP * fxRate,
            rawPrice: rawP,
            qty: q,
            total: runningTotal,
          ));
        }
      }
    }
    return entries;
  }

  void processRawDepth(dynamic bidsRaw, dynamic asksRaw, {required bool isLive}) {
    if (isDisposed) return;
    final rate = CurrencyFormatters.usdToInr;
    final bids = parseEntries(bidsRaw, rate);
    final asks = parseEntries(asksRaw, rate);

    if (bids.isEmpty && asks.isEmpty) return;

    double maxQty = 0.0001;
    for (final b in bids) {
      if (b.qty > maxQty) maxQty = b.qty;
    }
    for (final a in asks) {
      if (a.qty > maxQty) maxQty = a.qty;
    }

    final newState = OrderBookState(
      bids: bids,
      asks: asks,
      maxQty: maxQty,
      isLoading: false,
      isLive: isLive,
      lastUpdated: DateTime.now(),
    );

    if (currentState.isLoading) {
      emitState(newState);
    } else {
      pendingState = newState;
    }
  }

  void connectWebSocket() {
    if (isDisposed) return;
    try {
      channel?.sink.close();
      final streamName = '${pair.toLowerCase()}@depth20@100ms';
      final wsUri = isFutures
          ? Uri.parse('wss://fstream.binance.com/ws/$streamName')
          : Uri.parse('wss://stream.binance.com:9443/ws/$streamName');

      channel = WebSocketChannel.connect(wsUri);

      channel!.stream.listen(
        (message) {
          if (isDisposed) return;
          try {
            final decoded = jsonDecode(message as String);
            if (decoded is! Map<String, dynamic>) return;

            final bidsJson = decoded['bids'] ?? decoded['b'];
            final asksJson = decoded['asks'] ?? decoded['a'];

            if (bidsJson != null && asksJson != null) {
              processRawDepth(bidsJson, asksJson, isLive: true);
            }
          } catch (_) {}
        },
        onError: (_) {
          if (!isDisposed) {
            reconnectTimer?.cancel();
            reconnectTimer = Timer(const Duration(seconds: 3), connectWebSocket);
          }
        },
        onDone: () {
          if (!isDisposed) {
            reconnectTimer?.cancel();
            reconnectTimer = Timer(const Duration(seconds: 3), connectWebSocket);
          }
        },
        cancelOnError: false,
      );
    } catch (_) {
      if (!isDisposed) {
        reconnectTimer?.cancel();
        reconnectTimer = Timer(const Duration(seconds: 3), connectWebSocket);
      }
    }
  }

  Future<void> fetchSnapshot() async {
    try {
      final url = isFutures
          ? 'https://fapi.binance.com/fapi/v1/depth?symbol=$pair&limit=20'
          : 'https://api.binance.com/api/v3/depth?symbol=$pair&limit=20';

      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (isDisposed) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        processRawDepth(data['bids'], data['asks'], isLive: false);
      }
    } catch (_) {}
  }

  // Initial loading state
  controller.add(currentState);

  // Start snapshot and live stream
  fetchSnapshot();
  connectWebSocket();

  // Throttle timer for smooth 5 FPS updates
  throttleTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
    if (isDisposed || controller.isClosed) return;
    if (pendingState != null) {
      emitState(pendingState!);
      pendingState = null;
    }
  });

  ref.onDispose(() {
    isDisposed = true;
    throttleTimer?.cancel();
    reconnectTimer?.cancel();
    channel?.sink.close();
    controller.close();
  });

  return controller.stream;
});
