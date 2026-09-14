import 'dart:math' as math;

String uid() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${math.Random().nextInt(9999).toRadixString(36)}';

class Counter {
  String id, name, group, symbol;
  double value, step, mult;
  double? moneyValue, moneyStep;
  bool moneyEnabled;
  double? goalV, goalM;
  String goalAction;
  bool pinned, stopped;
  int order;

  Counter({
    required this.id,
    required this.name,
    this.group = '',
    this.symbol = '€',
    this.value = 0,
    this.step = 1,
    this.mult = 1,
    this.moneyValue,
    this.moneyStep,
    this.moneyEnabled = false,
    this.goalV,
    this.goalM,
    this.goalAction = 'continue',
    this.pinned = false,
    this.stopped = false,
    this.order = 0,
  });

  bool get usesManualMoney => moneyEnabled && moneyStep != null;

  double get money => !moneyEnabled || mult == 0
      ? 0
      : (usesManualMoney ? (moneyValue ?? 0) : value * mult);

  void ensureMoneySeed() {
    if (usesManualMoney && moneyValue == null) moneyValue = value * mult;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'group': group,
        'symbol': symbol,
        'value': value,
        'step': step,
        'mult': mult,
        'moneyValue': moneyValue,
        'moneyStep': moneyStep,
        'moneyEnabled': moneyEnabled,
        'goalV': goalV,
        'goalM': goalM,
        'goalAction': goalAction,
        'pinned': pinned,
        'stopped': stopped,
        'order': order,
      };

  factory Counter.fromJson(Map<String, dynamic> j) => Counter(
        id: j['id'] as String? ?? uid(),
        name: j['name'] as String? ?? 'Counter',
        group: j['group'] as String? ?? '',
        symbol: j['symbol'] as String? ?? '€',
        value: (j['value'] as num? ?? 0).toDouble(),
        step: (j['step'] as num? ?? 1).toDouble(),
        mult: (j['mult'] as num? ?? 1).toDouble(),
        moneyValue: (j['moneyValue'] as num?)?.toDouble(),
        moneyStep: (j['moneyStep'] as num?)?.toDouble(),
        moneyEnabled: j['moneyEnabled'] as bool? ??
            ((j['moneyStep'] as num?) != null || (j['goalM'] as num?) != null),
        goalV: (j['goalV'] as num?)?.toDouble(),
        goalM: (j['goalM'] as num?)?.toDouble(),
        goalAction: j['goalAction'] as String? ?? 'continue',
        pinned: j['pinned'] as bool? ?? false,
        stopped: j['stopped'] as bool? ?? false,
        order: (j['order'] as num? ?? 0).toInt(),
      )..ensureMoneySeed();
}
