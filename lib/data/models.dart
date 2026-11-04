import 'package:cloud_firestore/cloud_firestore.dart';

class StockCandle {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const StockCandle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}

class Stock {
  const Stock({
    required this.symbol,
    required this.name,
    required this.category,
    required this.currentPrice,
    required this.previousClose,
    required this.dayHigh,
    required this.dayLow,
    required this.volume,
    required this.history,
    required this.candleHistory,
    required this.about,
    required this.supply,
    required this.rank,
    this.isLive = false,
  });

  final String symbol;
  final String name;
  final String category;
  final double currentPrice;
  final double previousClose;
  final double dayHigh;
  final double dayLow;
  final int volume;
  final List<double> history;
  final List<StockCandle> candleHistory;
  final String about;
  final double supply;
  final int rank;
  final bool isLive;

  double get change => currentPrice - previousClose;
  double get changePercentage => (previousClose == 0 || previousClose.isNaN) ? 0.0 : ((change / previousClose) * 100);
  double get marketCap => currentPrice * supply;

  Stock copyWith({
    double? currentPrice,
    double? previousClose,
    double? dayHigh,
    double? dayLow,
    int? volume,
    bool? isLive,
  }) {
    return Stock(
      symbol: symbol,
      name: name,
      category: category,
      currentPrice: currentPrice ?? this.currentPrice,
      previousClose: previousClose ?? this.previousClose,
      dayHigh: dayHigh ?? this.dayHigh,
      dayLow: dayLow ?? this.dayLow,
      volume: volume ?? this.volume,
      history: history,
      candleHistory: candleHistory,
      about: about,
      supply: supply,
      rank: rank,
      isLive: isLive ?? this.isLive,
    );
  }
}

class Holding {
  const Holding({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
  });
  final String symbol;
  final int quantity;
  final double averagePrice;

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'quantity': quantity,
    'averagePrice': averagePrice,
  };

  factory Holding.fromJson(Map<String, dynamic> json) => Holding(
    symbol: json['symbol'] as String,
    quantity: json['quantity'] as int,
    averagePrice: (json['averagePrice'] as num).toDouble(),
  );
}

enum OrderSide { buy, sell }

class Trade {
  const Trade({
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.price,
    required this.time,
  });
  final String symbol;
  final OrderSide side;
  final int quantity;
  final double price;
  final DateTime time;

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'side': side.name,
    'quantity': quantity,
    'price': price,
    'time': time.toIso8601String(),
  };

  factory Trade.fromJson(Map<String, dynamic> json) => Trade(
    symbol: json['symbol'] as String,
    side: OrderSide.values.firstWhere((e) => e.name == json['side']),
    quantity: json['quantity'] as int,
    price: (json['price'] as num).toDouble(),
    time: DateTime.parse(json['time'] as String),
  );
}

class SpotLimitOrder {
  final String id;
  final String symbol;
  final OrderSide side;
  final int quantity;
  final double targetPrice;
  final double reservedAmount;
  final DateTime createdAt;
  final String status; // 'pending', 'executed', 'cancelled'

  const SpotLimitOrder({
    required this.id,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.targetPrice,
    required this.reservedAmount,
    required this.createdAt,
    this.status = 'pending',
  });

  SpotLimitOrder copyWith({
    String? status,
  }) {
    return SpotLimitOrder(
      id: id,
      symbol: symbol,
      side: side,
      quantity: quantity,
      targetPrice: targetPrice,
      reservedAmount: reservedAmount,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'side': side.name,
    'quantity': quantity,
    'targetPrice': targetPrice,
    'reservedAmount': reservedAmount,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
  };

  factory SpotLimitOrder.fromJson(Map<String, dynamic> json) => SpotLimitOrder(
    id: json['id'] as String,
    symbol: json['symbol'] as String,
    side: OrderSide.values.firstWhere((e) => e.name == json['side']),
    quantity: json['quantity'] as int,
    targetPrice: (json['targetPrice'] as num).toDouble(),
    reservedAmount: (json['reservedAmount'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: json['status'] as String? ?? 'pending',
  );
}

class FuturesPosition {
  const FuturesPosition({
    required this.id,
    required this.symbol,
    required this.side,
    required this.leverage,
    required this.entryPrice,
    required this.quantity,
    required this.margin,
  });

  final String id;
  final String symbol;
  final OrderSide side;
  final int leverage;
  final double entryPrice;
  final double quantity;
  final double margin;

  double get liquidationPrice {
    if (side == OrderSide.buy) {
      return entryPrice - (entryPrice / leverage);
    } else {
      return entryPrice + (entryPrice / leverage);
    }
  }

  bool isLiquidated(double currentPrice) {
    if (currentPrice <= 0) return false;
    if (side == OrderSide.buy) {
      return currentPrice <= liquidationPrice;
    } else {
      return currentPrice >= liquidationPrice;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'side': side.name,
    'leverage': leverage,
    'entryPrice': entryPrice,
    'quantity': quantity,
    'margin': margin,
  };

  factory FuturesPosition.fromJson(Map<String, dynamic> json) => FuturesPosition(
    id: json['id'] as String,
    symbol: json['symbol'] as String,
    side: OrderSide.values.firstWhere((e) => e.name == json['side']),
    leverage: json['leverage'] as int,
    entryPrice: (json['entryPrice'] as num).toDouble(),
    quantity: (json['quantity'] as num).toDouble(),
    margin: (json['margin'] as num).toDouble(),
  );
}

class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.reward,
    required this.target,
    this.progress = 0,
    this.completed = false,
  });
  final String id;
  final String title;
  final int reward;
  final int target;
  final int progress;
  final bool completed;

  Mission copyWith({int? progress, bool? completed}) {
    return Mission(
      id: id,
      title: title,
      reward: reward,
      target: target,
      progress: progress ?? this.progress,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'reward': reward,
    'target': target,
    'progress': progress,
    'completed': completed,
  };

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
    id: json['id'] as String,
    title: json['title'] as String,
    reward: json['reward'] as int? ?? 100,
    target: json['target'] as int? ?? 1,
    progress: json['progress'] as int? ?? 0,
    completed: json['completed'] as bool? ?? false,
  );
}

class Badge {
  final String id;
  final String title;
  final String description;
  final String icon;

  const Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

const ALL_BADGES = [
  Badge(id: 'b1', title: 'First Blood', description: 'Make your first trade', icon: '🩸'),
  Badge(id: 'b2', title: 'Active Trader', description: 'Make 10 trades', icon: '⚡'),
  Badge(id: 'b3', title: 'Whale Status', description: 'Reach 2,00,00,000 balance', icon: '🐋'),
  Badge(id: 'b4', title: 'Diamond Hands', description: 'Hold any asset', icon: '💎'),
  Badge(id: 'b5', title: 'Diversified', description: 'Hold 3 different assets', icon: '🌐'),
  Badge(id: 'b6', title: 'Blitz Gladiator', description: 'Win a 1v1 Blitz Battle', icon: '⚔️'),
  Badge(id: 'b7', title: 'Weekly Podium', description: 'Finish Top 3 in Weekly Championship', icon: '🏆'),
];

class UserProfile {
  const UserProfile({
    required this.name,
    required this.experienceLevel,
    required this.virtualBalance,
    required this.xp,
    required this.streak,
    required this.watchlist,
    this.publicUid = '',
    this.unlockedBadges = const {},
    this.completedMissions = const {},
    this.preferredCurrency = 'USD',
    this.preferredLanguage = 'English',
    this.themeMode = 'Dark',
    this.lastDailyClaim,
    this.lastQuizAttempt,
    this.email = '',
    this.photoUrl = '',
    this.bio = 'Passionate paper trader & crypto enthusiast.',
    this.blitzRating = 1000,
    this.blitzWins = 0,
    this.blitzLosses = 0,
    this.isAiSignalsUnlocked = false,
    this.isBanned = false,
    this.banReason,
    this.bannedAt,
    this.claimedXpMilestones = const {},
  });
  final String name;
  final String experienceLevel;
  final double virtualBalance;
  final int xp;
  final int streak;
  final Set<String> watchlist;
  final String publicUid;
  final Set<String> unlockedBadges;
  final Set<String> completedMissions;
  final String preferredCurrency;
  final String preferredLanguage;
  final String themeMode;
  final String? lastDailyClaim;
  final String? lastQuizAttempt;
  final String email;
  final String photoUrl;
  final String bio;
  final int blitzRating;
  final int blitzWins;
  final int blitzLosses;
  final bool isAiSignalsUnlocked;
  final bool isBanned;
  final String? banReason;
  final String? bannedAt;
  final Set<String> claimedXpMilestones;

  static String getEvolvedTitle(int xp) {
    if (xp >= 20000) return 'Apex Legend';
    if (xp >= 10000) return 'Crypto Whale';
    if (xp >= 5000) return 'Pro Analyst';
    if (xp >= 2500) return 'Market Maestro';
    if (xp >= 1000) return 'Strategy Captain';
    if (xp >= 500) return 'Momentum Trader';
    if (xp >= 250) return 'Apprentice Trader';
    return 'Rookie Trader';
  }

  String get evolvedTitle => getEvolvedTitle(xp);

  UserProfile copyWith({
    String? name,
    String? experienceLevel,
    double? virtualBalance,
    int? xp,
    int? streak,
    Set<String>? watchlist,
    String? publicUid,
    Set<String>? unlockedBadges,
    Set<String>? completedMissions,
    String? preferredCurrency,
    String? preferredLanguage,
    String? themeMode,
    String? lastDailyClaim,
    String? lastQuizAttempt,
    String? email,
    String? photoUrl,
    String? bio,
    int? blitzRating,
    int? blitzWins,
    int? blitzLosses,
    bool? isAiSignalsUnlocked,
    bool? isBanned,
    String? banReason,
    String? bannedAt,
    Set<String>? claimedXpMilestones,
  }) {
    return UserProfile(
      name: name ?? this.name,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      virtualBalance: virtualBalance ?? this.virtualBalance,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      watchlist: watchlist ?? this.watchlist,
      publicUid: publicUid ?? this.publicUid,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      completedMissions: completedMissions ?? this.completedMissions,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      themeMode: themeMode ?? this.themeMode,
      lastDailyClaim: lastDailyClaim ?? this.lastDailyClaim,
      lastQuizAttempt: lastQuizAttempt ?? this.lastQuizAttempt,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      blitzRating: blitzRating ?? this.blitzRating,
      blitzWins: blitzWins ?? this.blitzWins,
      blitzLosses: blitzLosses ?? this.blitzLosses,
      isAiSignalsUnlocked: isAiSignalsUnlocked ?? this.isAiSignalsUnlocked,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      bannedAt: bannedAt ?? this.bannedAt,
      claimedXpMilestones: claimedXpMilestones ?? this.claimedXpMilestones,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'experienceLevel': experienceLevel,
    'virtualBalance': virtualBalance,
    'xp': xp,
    'streak': streak,
    'watchlist': watchlist.toList(),
    'publicUid': publicUid,
    'unlockedBadges': unlockedBadges.toList(),
    'completedMissions': completedMissions.toList(),
    'preferredCurrency': preferredCurrency,
    'preferredLanguage': preferredLanguage,
    'themeMode': themeMode,
    'lastDailyClaim': lastDailyClaim,
    'lastQuizAttempt': lastQuizAttempt,
    'email': email,
    'photoUrl': photoUrl,
    'bio': bio,
    'blitzRating': blitzRating,
    'blitzWins': blitzWins,
    'blitzLosses': blitzLosses,
    'isAiSignalsUnlocked': isAiSignalsUnlocked,
    'isBanned': isBanned,
    'banReason': banReason,
    'bannedAt': bannedAt,
    'claimedXpMilestones': claimedXpMilestones.toList(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? 'Guest',
    experienceLevel: json['experienceLevel'] as String? ?? 'Beginner',
    virtualBalance: (json['virtualBalance'] as num?)?.toDouble() ?? 0.0,
    xp: json['xp'] as int? ?? 0,
    streak: json['streak'] as int? ?? 1,
    watchlist: Set<String>.from(json['watchlist'] as List? ?? []),
    publicUid: json['publicUid'] as String? ?? '',
    unlockedBadges: Set<String>.from(json['unlockedBadges'] as List? ?? []),
    completedMissions: Set<String>.from(json['completedMissions'] as List? ?? []),
    preferredCurrency: json['preferredCurrency'] as String? ?? 'USD',
    preferredLanguage: json['preferredLanguage'] as String? ?? 'English',
    themeMode: json['themeMode'] as String? ?? 'Dark',
    lastDailyClaim: json['lastDailyClaim'] as String?,
    lastQuizAttempt: json['lastQuizAttempt'] as String?,
    email: json['email'] as String? ?? '',
    photoUrl: json['photoUrl'] as String? ?? '',
    bio: json['bio'] as String? ?? 'Passionate paper trader & crypto enthusiast.',
    blitzRating: json['blitzRating'] as int? ?? 1000,
    blitzWins: json['blitzWins'] as int? ?? 0,
    blitzLosses: json['blitzLosses'] as int? ?? 0,
    isAiSignalsUnlocked: json['isAiSignalsUnlocked'] as bool? ?? false,
    isBanned: json['isBanned'] as bool? ?? false,
    banReason: json['banReason'] as String?,
    bannedAt: json['bannedAt']?.toString(),
    claimedXpMilestones: Set<String>.from(json['claimedXpMilestones'] as List? ?? []),
  );
}

class MoneyRequest {
  const MoneyRequest({
    required this.id,
    required this.requesterUid,
    required this.requesterId,
    required this.amount,
    required this.reason,
    required this.requesterNetWorth,
    required this.status, // 'pending', 'approved', 'rejected'
    this.adminMessage,
    this.createdAt,
    this.previousBalance,
    this.newBalance,
    this.inrAmount,
    this.paymentId,
    this.paymentMethod,
    this.utrNumber,
  });

  final String id;
  final String requesterUid;
  final String requesterId;
  final double amount;
  final String reason;
  final double requesterNetWorth;
  final String status;
  final String? adminMessage;
  final DateTime? createdAt;
  final double? previousBalance;
  final double? newBalance;
  final double? inrAmount;
  final String? paymentId;
  final String? paymentMethod;
  final String? utrNumber;

  Map<String, dynamic> toJson() => {
    'id': id,
    'requesterUid': requesterUid,
    'requesterId': requesterId,
    'amount': amount,
    'reason': reason,
    'requesterNetWorth': requesterNetWorth,
    'status': status,
    if (adminMessage != null) 'adminMessage': adminMessage,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (previousBalance != null) 'previousBalance': previousBalance,
    if (newBalance != null) 'newBalance': newBalance,
    if (inrAmount != null) 'inrAmount': inrAmount,
    if (paymentId != null) 'paymentId': paymentId,
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
    if (utrNumber != null) 'utrNumber': utrNumber,
  };

  factory MoneyRequest.fromJson(Map<String, dynamic> json) => MoneyRequest(
    id: json['id'] as String? ?? '',
    requesterUid: json['requesterUid'] as String? ?? '',
    requesterId: json['requesterId'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    reason: json['reason'] as String? ?? '',
    requesterNetWorth: (json['requesterNetWorth'] as num?)?.toDouble() ?? 0.0,
    status: json['status'] as String? ?? 'pending',
    adminMessage: json['adminMessage'] as String?,
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    previousBalance: (json['previousBalance'] as num?)?.toDouble(),
    newBalance: (json['newBalance'] as num?)?.toDouble(),
    inrAmount: (json['inrAmount'] as num?)?.toDouble(),
    paymentId: json['paymentId'] as String?,
    paymentMethod: json['paymentMethod'] as String?,
    utrNumber: json['utrNumber'] as String?,
  );

}

class AttachedTradeInfo {
  final String symbol;
  final bool isLong;
  final int leverage;
  final double entryPrice;
  final double currentPrice;
  final double pnlPercentage;
  final double? targetPrice;
  final double? stopLossPrice;

  const AttachedTradeInfo({
    required this.symbol,
    required this.isLong,
    required this.leverage,
    required this.entryPrice,
    required this.currentPrice,
    required this.pnlPercentage,
    this.targetPrice,
    this.stopLossPrice,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'isLong': isLong,
        'leverage': leverage,
        'entryPrice': entryPrice,
        'currentPrice': currentPrice,
        'pnlPercentage': pnlPercentage,
        'targetPrice': targetPrice,
        'stopLossPrice': stopLossPrice,
      };

  factory AttachedTradeInfo.fromJson(Map<String, dynamic> json) => AttachedTradeInfo(
        symbol: json['symbol'] as String,
        isLong: json['isLong'] as bool? ?? true,
        leverage: json['leverage'] as int? ?? 1,
        entryPrice: (json['entryPrice'] as num).toDouble(),
        currentPrice: (json['currentPrice'] as num).toDouble(),
        pnlPercentage: (json['pnlPercentage'] as num).toDouble(),
        targetPrice: (json['targetPrice'] as num?)?.toDouble(),
        stopLossPrice: (json['stopLossPrice'] as num?)?.toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachedTradeInfo &&
          runtimeType == other.runtimeType &&
          symbol == other.symbol &&
          isLong == other.isLong &&
          leverage == other.leverage &&
          entryPrice == other.entryPrice;

  @override
  int get hashCode => Object.hash(symbol, isLong, leverage, entryPrice);
}

class CommunityPost {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String authorBadge;
  final String content;
  final DateTime timestamp;
  final AttachedTradeInfo? attachedTrade;
  final int likesCount;
  final int commentsCount;
  final int tipsReceived;
  final bool isLikedByMe;
  final int agreeCount;
  final int disagreeCount;
  final String? myVote;
  final List<String> hashtags;

  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.authorBadge,
    required this.content,
    required this.timestamp,
    this.attachedTrade,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.tipsReceived = 0,
    this.isLikedByMe = false,
    this.agreeCount = 0,
    this.disagreeCount = 0,
    this.myVote,
    this.hashtags = const [],
  });

  int get totalVotes => agreeCount + disagreeCount;
  int get agreePercentage => totalVotes == 0 ? 100 : ((agreeCount / totalVotes) * 100).round();

  CommunityPost copyWith({
    int? likesCount,
    int? commentsCount,
    int? tipsReceived,
    bool? isLikedByMe,
    int? agreeCount,
    int? disagreeCount,
    String? myVote,
  }) {
    return CommunityPost(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      authorBadge: authorBadge,
      content: content,
      timestamp: timestamp,
      attachedTrade: attachedTrade,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      tipsReceived: tipsReceived ?? this.tipsReceived,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      agreeCount: agreeCount ?? this.agreeCount,
      disagreeCount: disagreeCount ?? this.disagreeCount,
      myVote: myVote ?? this.myVote,
      hashtags: hashtags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'authorBadge': authorBadge,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (attachedTrade != null) 'attachedTrade': attachedTrade!.toJson(),
        'likesCount': likesCount,
        'commentsCount': commentsCount,
        'tipsReceived': tipsReceived,
        'agreeCount': agreeCount,
        'disagreeCount': disagreeCount,
        'hashtags': hashtags,
      };

  factory CommunityPost.fromJson(Map<String, dynamic> json, {String currentUserId = ''}) {
    final votesMap = (json['votes'] as Map<String, dynamic>?) ?? {};
    final userVote = votesMap[currentUserId] as String?;

    DateTime parseTimestamp(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return CommunityPost(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'CryptoTrader',
      authorAvatar: json['authorAvatar'] as String? ?? '',
      authorBadge: json['authorBadge'] as String? ?? 'Paper Trader',
      content: json['content'] as String? ?? '',
      timestamp: parseTimestamp(json['timestamp']),
      attachedTrade: json['attachedTrade'] != null
          ? AttachedTradeInfo.fromJson(json['attachedTrade'] as Map<String, dynamic>)
          : null,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      tipsReceived: (json['tipsReceived'] as num?)?.toInt() ?? 0,
      isLikedByMe: (json['likedBy'] as List?)?.contains(currentUserId) ?? false,
      agreeCount: (json['agreeCount'] as num?)?.toInt() ?? 0,
      disagreeCount: (json['disagreeCount'] as num?)?.toInt() ?? 0,
      myVote: userVote,
      hashtags: (json['hashtags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

class PostComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String text;
  final DateTime timestamp;

  const PostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PostComment.fromJson(Map<String, dynamic> json) {
    DateTime parseTimestamp(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return PostComment(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'Trader',
      authorAvatar: json['authorAvatar'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: parseTimestamp(json['timestamp']),
    );
  }
}

class PublicUserProfile {
  final String id;
  final String username;
  final String avatarUrl;
  final String bio;
  final double winRate;
  final int totalTrades;
  final String rankTitle;
  final bool isFollowing;
  final int sharedPostsCount;
  final int followersCount;

  const PublicUserProfile({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.bio,
    required this.winRate,
    required this.totalTrades,
    required this.rankTitle,
    this.isFollowing = false,
    this.sharedPostsCount = 0,
    this.followersCount = 0,
  });

  PublicUserProfile copyWith({
    bool? isFollowing,
    int? sharedPostsCount,
    int? followersCount,
  }) {
    return PublicUserProfile(
      id: id,
      username: username,
      avatarUrl: avatarUrl,
      bio: bio,
      winRate: winRate,
      totalTrades: totalTrades,
      rankTitle: rankTitle,
      isFollowing: isFollowing ?? this.isFollowing,
      sharedPostsCount: sharedPostsCount ?? this.sharedPostsCount,
      followersCount: followersCount ?? this.followersCount,
    );
  }
}

class XpMilestone {
  final String id;
  final int requiredXp;
  final int level;
  final double cashReward;
  final String titleUnlocked;
  final String badgeIcon;
  final String description;

  const XpMilestone({
    required this.id,
    required this.requiredXp,
    required this.level,
    required this.cashReward,
    required this.titleUnlocked,
    required this.badgeIcon,
    required this.description,
  });
}

enum NotificationCategory {
  all,
  trade,
  social,
  prize,
  system,
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationCategory category;
  final String type; // 'order_fill', 'liquidation', 'tp_sl', 'like', 'comment', 'follow', 'tip', 'prize', 'quest'
  final DateTime createdAt;
  final bool isRead;
  final String? avatarUrl;
  final Map<String, dynamic> data;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.category,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.avatarUrl,
    this.data = const {},
  });

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationCategory? category,
    String? type,
    DateTime? createdAt,
    bool? isRead,
    String? avatarUrl,
    Map<String, dynamic>? data,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      data: data ?? this.data,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'message': message,
        'category': category.name,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'avatarUrl': avatarUrl,
        'data': data,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      category: NotificationCategory.values.firstWhere(
        (c) => c.name == (json['category'] as String?),
        orElse: () => NotificationCategory.system,
      ),
      type: json['type'] as String? ?? 'system',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp
              ? (json['createdAt'] as Timestamp).toDate()
              : (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()))
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      avatarUrl: json['avatarUrl'] as String?,
      data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : {},
    );
  }
}





