// widgetdieukhien.dart
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:testproject/ultis/listcambien.dart' as globals;

enum CommandType { ifCmd, setCmd, delayCmd, setServoCmd, whileCmd, forCmd }

class Condition {
  List<String> leftTokens;
  String comparator;
  List<String> rightTokens;

  Condition({
    List<String>? leftTokens,
    this.comparator = '>',
    List<String>? rightTokens,
  })  : leftTokens = leftTokens ?? [],
        rightTokens = rightTokens ?? [];

  String summary() {
    return '${leftTokens.join(" ")} $comparator ${rightTokens.join(" ")}';
  }

  // ==== thêm vào đây ====
  Map<String, dynamic> toJson() => {
        'leftTokens': leftTokens,
        'comparator': comparator,
        'rightTokens': rightTokens,
      };

  factory Condition.fromJson(Map<String, dynamic> json) => Condition(
        leftTokens: List<String>.from(json['leftTokens'] ?? []),
        comparator: json['comparator'] ?? '>',
        rightTokens: List<String>.from(json['rightTokens'] ?? []),
      );
}

class CommandModel {
  final String id = const Uuid().v4();
  CommandType type;

  // SET
  String target;
  List<String> expressionTokens; // token list

  // SERVO
  List<String> servoTokens;

  // DELAY (ms)
  int delayMs;

  // IF / WHILE
  List<Condition> conditions;
  List<String> betweenOps;
  List<CommandModel> thenActions; // THEN / DO / body
  List<CommandModel> elseActions; // ELSE (IF)

  // FOR-specific (improved)
  String loopVar; // e.g. 'i'
  List<String> initTokens; // init expression
  List<String> condLeftTokens; // left expr of condition
  String condComparator; // '<', '>', etc
  List<String> condRightTokens; // right expr of condition
  List<String> stepTokens; // step increment expression (we'll add to loopVar)

  // constructors
  CommandModel.set({
    this.target = 'D3',
    List<String>? expressionTokens,
  })  : type = CommandType.setCmd,
        expressionTokens = expressionTokens ?? [],
        servoTokens = [],
        delayMs = 0,
        conditions = [],
        betweenOps = [],
        thenActions = [],
        elseActions = [],
        loopVar = '',
        initTokens = [],
        condLeftTokens = [],
        condComparator = '<',
        condRightTokens = [],
        stepTokens = [];

  CommandModel.delay({
    this.delayMs = 1000,
  })  : type = CommandType.delayCmd,
        target = '',
        expressionTokens = [],
        servoTokens = [],
        conditions = [],
        betweenOps = [],
        thenActions = [],
        elseActions = [],
        loopVar = '',
        initTokens = [],
        condLeftTokens = [],
        condComparator = '<',
        condRightTokens = [],
        stepTokens = [];

  CommandModel.ifCmd({
    List<Condition>? conditions,
    List<String>? betweenOps,
    List<CommandModel>? thenActions,
    List<CommandModel>? elseActions,
  })  : type = CommandType.ifCmd,
        target = '',
        expressionTokens = [],
        servoTokens = [],
        delayMs = 0,
        conditions = conditions ?? [Condition()],
        betweenOps = betweenOps ?? [],
        thenActions = thenActions ?? [],
        elseActions = elseActions ?? [],
        loopVar = '',
        initTokens = [],
        condLeftTokens = [],
        condComparator = '<',
        condRightTokens = [],
        stepTokens = [];

  CommandModel.setServo({
    this.target = 'D3',
    List<String>? servoTokens,
  })  : type = CommandType.setServoCmd,
        expressionTokens = [],
        servoTokens = servoTokens ?? [],
        delayMs = 0,
        conditions = [],
        betweenOps = [],
        thenActions = [],
        elseActions = [],
        loopVar = '',
        initTokens = [],
        condLeftTokens = [],
        condComparator = '<',
        condRightTokens = [],
        stepTokens = [];

  CommandModel.whileCmd({
    List<Condition>? conditions,
    List<String>? betweenOps,
    List<CommandModel>? doActions,
  })  : type = CommandType.whileCmd,
        target = '',
        expressionTokens = [],
        servoTokens = [],
        delayMs = 0,
        conditions = conditions ?? [Condition()],
        betweenOps = betweenOps ?? [],
        thenActions = doActions ?? [],
        elseActions = [],
        loopVar = '',
        initTokens = [],
        condLeftTokens = [],
        condComparator = '<',
        condRightTokens = [],
        stepTokens = [];

  CommandModel.forCmd({
    this.loopVar = 'i',
    List<String>? initTokens,
    List<String>? condLeftTokens,
    String? condComparator,
    List<String>? condRightTokens,
    List<String>? stepTokens,
    List<CommandModel>? body,
  })  : type = CommandType.forCmd,
        target = '',
        expressionTokens = [],
        servoTokens = [],
        delayMs = 0,
        conditions = [],
        betweenOps = [],
        thenActions = body ?? [],
        elseActions = [],
        initTokens = initTokens ?? ['0'],
        condLeftTokens = condLeftTokens ?? [loopVar],
        condComparator = condComparator ?? '<',
        condRightTokens = condRightTokens ?? ['10'],
        stepTokens = stepTokens ?? ['1'];

  void dispose() {
    for (var a in thenActions) {
      a.dispose();
    }
    for (var a in elseActions) {
      a.dispose();
    }
  }

  String summary() {
    switch (type) {
      case CommandType.setCmd:
        return 'SET $target = ${expressionTokens.join(' ')}';
      case CommandType.setServoCmd:
        return 'SET_SERVO $target = ${servoTokens.join(" ")}';
      case CommandType.delayCmd:
        return 'DELAY ${delayMs}ms';
      case CommandType.ifCmd:
        final conds = conditions
            .map((c) => c.summary())
            .join(' ${betweenOps.isNotEmpty ? betweenOps[0] : 'AND'} ');
        return 'IF ($conds) THEN ${thenActions.length} ELSE ${elseActions.length}';
      case CommandType.whileCmd:
        final conds = conditions
            .map((c) => c.summary())
            .join(' ${betweenOps.isNotEmpty ? betweenOps[0] : 'AND'} ');
        return 'WHILE ($conds) DO ${thenActions.length}';
      case CommandType.forCmd:
        final ini = initTokens.isEmpty ? '?' : initTokens.join(' ');
        final left = condLeftTokens.isEmpty ? '?' : condLeftTokens.join(' ');
        final right = condRightTokens.isEmpty ? '?' : condRightTokens.join(' ');
        final step = stepTokens.isEmpty ? '?' : stepTokens.join(' ');
        return 'FOR (${loopVar} = $ini; $left $condComparator $right; ${loopVar} += $step) DO ${thenActions.length}';
    }
  }

  // ==== thêm vào đây ====
  Map<String, dynamic> toJson() => {
        'type': type.index,
        'target': target,
        'expressionTokens': expressionTokens,
        'servoTokens': servoTokens,
        'delayMs': delayMs,
        'conditions': conditions.map((c) => c.toJson()).toList(),
        'betweenOps': betweenOps,
        'thenActions': thenActions.map((a) => a.toJson()).toList(),
        'elseActions': elseActions.map((a) => a.toJson()).toList(),
        'loopVar': loopVar,
        'initTokens': initTokens,
        'condLeftTokens': condLeftTokens,
        'condComparator': condComparator,
        'condRightTokens': condRightTokens,
        'stepTokens': stepTokens,
      };

  factory CommandModel.fromJson(Map<String, dynamic> json) {
    final type = CommandType.values[json['type']];
    switch (type) {
      case CommandType.setCmd:
        return CommandModel.set(
          target: json['target'],
          expressionTokens: List<String>.from(json['expressionTokens'] ?? []),
        );
      case CommandType.setServoCmd:
        return CommandModel.setServo(
          target: json['target'],
          servoTokens: List<String>.from(json['servoTokens'] ?? []),
        );
      case CommandType.delayCmd:
        return CommandModel.delay(
          delayMs: json['delayMs'] ?? 1000,
        );
      case CommandType.ifCmd:
        return CommandModel.ifCmd(
          conditions: (json['conditions'] as List? ?? [])
              .map((c) => Condition.fromJson(c))
              .toList(),
          betweenOps: List<String>.from(json['betweenOps'] ?? []),
          thenActions: (json['thenActions'] as List? ?? [])
              .map((a) => CommandModel.fromJson(a))
              .toList(),
          elseActions: (json['elseActions'] as List? ?? [])
              .map((a) => CommandModel.fromJson(a))
              .toList(),
        );
      case CommandType.whileCmd:
        return CommandModel.whileCmd(
          conditions: (json['conditions'] as List? ?? [])
              .map((c) => Condition.fromJson(c))
              .toList(),
          betweenOps: List<String>.from(json['betweenOps'] ?? []),
          doActions: (json['thenActions'] as List? ?? [])
              .map((a) => CommandModel.fromJson(a))
              .toList(),
        );
      case CommandType.forCmd:
        return CommandModel.forCmd(
          loopVar: json['loopVar'] ?? 'i',
          initTokens: List<String>.from(json['initTokens'] ?? ['0']),
          condLeftTokens: List<String>.from(json['condLeftTokens'] ?? ['i']),
          condComparator: json['condComparator'] ?? '<',
          condRightTokens: List<String>.from(json['condRightTokens'] ?? ['10']),
          stepTokens: List<String>.from(json['stepTokens'] ?? ['1']),
          body: (json['thenActions'] as List? ?? [])
              .map((a) => CommandModel.fromJson(a))
              .toList(),
        );
    }
  }
}

// ================= LOGIC =================

Future<void> executeCommands(
  List<CommandModel> commands,
  Map<String, double> sensorValues,
  Map<String, double> variables,
  void Function(int, String, double) onSet, {
  required bool Function() stopFlag,
  void Function(String msg)? onError,
}) async {
  for (var cmd in List<CommandModel>.from(commands)) {
    if (stopFlag()) return;

    try {
      if (cmd.type == CommandType.setCmd) {
        final val = _evalExpression(
            cmd.expressionTokens, sensorValues, variables,
            onError: onError);
        if (variables.containsKey(cmd.target)) {
          variables[cmd.target] = val;
        } else {
          onSet(1, cmd.target, val);
        }
      } else if (cmd.type == CommandType.delayCmd) {
        // break delay into small increments so stopFlag can be checked
        int remaining = cmd.delayMs;
        const int chunk = 50;
        while (remaining > 0) {
          if (stopFlag()) return;
          await Future.delayed(
              Duration(milliseconds: (remaining > chunk) ? chunk : remaining));
          remaining -= chunk;
        }
      } else if (cmd.type == CommandType.ifCmd) {
        bool result = _evalConditions(
            cmd.conditions, cmd.betweenOps, sensorValues, variables,
            onError: onError);
        if (result) {
          await executeCommands(cmd.thenActions, sensorValues, variables, onSet,
              stopFlag: stopFlag, onError: onError);
        } else {
          await executeCommands(cmd.elseActions, sensorValues, variables, onSet,
              stopFlag: stopFlag, onError: onError);
        }
      } else if (cmd.type == CommandType.setServoCmd) {
        final val = _evalExpression(cmd.servoTokens, sensorValues, variables,
            onError: onError);
        onSet(2, cmd.target, val);
      } else if (cmd.type == CommandType.whileCmd) {
        int safety = 1000;
        while (!stopFlag() &&
            _evalConditions(
                cmd.conditions, cmd.betweenOps, sensorValues, variables,
                onError: onError) &&
            safety-- > 0) {
          await executeCommands(cmd.thenActions, sensorValues, variables, onSet,
              stopFlag: stopFlag, onError: onError);
        }
      } else if (cmd.type == CommandType.forCmd) {
        // FOR scoping: save old value and restore afterward (local variable behavior)
        final String varName = cmd.loopVar;
        final bool hadOld = variables.containsKey(varName);
        final double oldVal = variables[varName] ?? 0;

        // init
        final double init = _evalExpression(
            cmd.initTokens, sensorValues, variables,
            onError: onError);
        variables[varName] = init;

        int safety = 10000; // big safety to avoid infinite loop
        while (!stopFlag() && safety-- > 0) {
          // evaluate condition: left comparator right
          final double left = _evalExpression(
              cmd.condLeftTokens, sensorValues, variables,
              onError: onError);
          final double right = _evalExpression(
              cmd.condRightTokens, sensorValues, variables,
              onError: onError);
          bool condResult;
          switch (cmd.condComparator) {
            case '<':
              condResult = left < right;
              break;
            case '>':
              condResult = left > right;
              break;
            case '<=':
              condResult = left <= right;
              break;
            case '>=':
              condResult = left >= right;
              break;
            case '==':
              condResult = left == right;
              break;
            case '!=':
              condResult = left != right;
              break;
            default:
              onError?.call("Comparator không hợp lệ: ${cmd.condComparator}");
              condResult = false;
          }

          if (!condResult) break;

          // Execute body: note body can read/write variables including loopVar
          await executeCommands(cmd.thenActions, sensorValues, variables, onSet,
              stopFlag: stopFlag, onError: onError);
          if (stopFlag()) break;

          // update step: we interpret stepTokens as the increment to add to loopVar
          final double step = _evalExpression(
              cmd.stepTokens, sensorValues, variables,
              onError: onError);
          variables[varName] = (variables[varName] ?? 0) + step;
        }

        // restore old variable state (local scoping)
        if (hadOld) {
          variables[varName] = oldVal;
        } else {
          variables.remove(varName);
        }
      }
    } catch (e) {
      if (onError != null) {
        onError("Lỗi khi chạy lệnh ${cmd.type}: $e");
      }
      return;
    }
  }
}

/// Evaluate conditions list (for IF/WHILE)
bool _evalConditions(
  List<Condition> conditions,
  List<String> betweenOps,
  Map<String, double> sensors,
  Map<String, double> vars, {
  void Function(String msg)? onError,
}) {
  if (conditions.isEmpty) return false;

  bool res =
      _evalSingleCondition(conditions[0], sensors, vars, onError: onError);
  for (int i = 1; i < conditions.length; i++) {
    bool next =
        _evalSingleCondition(conditions[i], sensors, vars, onError: onError);
    String op = (i - 1) < betweenOps.length ? betweenOps[i - 1] : 'AND';
    if (op == 'AND') {
      res = res && next;
    } else {
      res = res || next;
    }
  }
  return res;
}

bool _evalSingleCondition(
  Condition cond,
  Map<String, double> sensors,
  Map<String, double> vars, {
  void Function(String msg)? onError,
}) {
  final leftVal =
      _evalExpression(cond.leftTokens, sensors, vars, onError: onError);
  final rightVal =
      _evalExpression(cond.rightTokens, sensors, vars, onError: onError);

  switch (cond.comparator) {
    case '>':
      return leftVal > rightVal;
    case '<':
      return leftVal < rightVal;
    case '==':
      return leftVal == rightVal;
    case '!=':
      return leftVal != rightVal;
    case '>=':
      return leftVal >= rightVal;
    case '<=':
      return leftVal <= rightVal;
    default:
      onError?.call("Toán tử so sánh không hợp lệ: ${cond.comparator}");
      return false;
  }
}

double _evalExpression(
  List<String> tokens,
  Map<String, double> sensors,
  Map<String, double> vars, {
  void Function(String)? onError,
}) {
  if (tokens.isEmpty) return 0;

  // Replace names with numbers
  List<String> exp = [];
  for (var t in tokens) {
    if (sensors.containsKey(t)) {
      exp.add(sensors[t]!.toString());
    } else if (vars.containsKey(t)) {
      exp.add(vars[t]!.toString());
    } else {
      exp.add(t);
    }
  }

  // Shunting-yard to postfix
  final precedence = {'+': 1, '-': 1, '*': 2, '/': 2, '%': 2};
  final output = <String>[];
  final stack = <String>[];

  for (var t in exp) {
    if (double.tryParse(t) != null) {
      output.add(t);
    } else if (precedence.containsKey(t)) {
      while (stack.isNotEmpty &&
          precedence.containsKey(stack.last) &&
          precedence[stack.last]! >= precedence[t]!) {
        output.add(stack.removeLast());
      }
      stack.add(t);
    } else if (t == 'abs') {
      stack.add(t);
    } else {
      onError?.call("Token không hợp lệ: $t");
    }
  }
  while (stack.isNotEmpty) {
    output.add(stack.removeLast());
  }

  // Evaluate postfix
  final st = <double>[];
  for (var t in output) {
    if (double.tryParse(t) != null) {
      st.add(double.parse(t));
    } else if (t == 'abs') {
      if (st.isEmpty) {
        onError?.call("Thiếu toán hạng cho abs");
        return 0;
      }
      st.add(st.removeLast().abs());
    } else {
      if (st.length < 2) {
        onError?.call("Thiếu toán hạng cho toán tử $t");
        return 0;
      }
      double b = st.removeLast();
      double a = st.removeLast();
      switch (t) {
        case '+':
          st.add(a + b);
          break;
        case '-':
          st.add(a - b);
          break;
        case '*':
          st.add(a * b);
          break;
        case '/':
          if (b == 0) {
            onError?.call("Lỗi: chia cho 0");
            return 0;
          }
          st.add(a / b);
          break;
        case '%':
          if (b == 0) {
            onError?.call("Lỗi: chia lấy dư với 0");
            return 0;
          }
          st.add(a % b);
          break;
      }
    }
  }

  return st.isNotEmpty ? st.last : 0;
}

// =============== UI ===============

class DieuKhienWidget extends StatefulWidget {
  const DieuKhienWidget(
      {super.key, required this.valueGate, required this.onDieuKhienChanged});

  final Map<String, double> valueGate;
  final void Function(Map<String, List<int>>) onDieuKhienChanged;

  @override
  State<DieuKhienWidget> createState() => _DieuKhienWidgetState();
}

class _DieuKhienWidgetState extends State<DieuKhienWidget> {
  final List<CommandModel> _commands = [];
  final Map<String, double> _variables = {};
  final List<String> _dPins = globals.dPins;
  final List<String> _sensors = ['A1', 'A2'];
  final ScrollController _varScrollController = ScrollController();
  bool _isRunning = false;
  bool _shouldStop = false;

  void _addVariable() {
    setState(() {
      String name = 'Var${_variables.length + 1}';
      _variables[name] = 0;
    });
  }

  void _addCommand(String type) {
    setState(() {
      if (type == 'IF') _commands.add(CommandModel.ifCmd());
      if (type == 'SET') _commands.add(CommandModel.set());
      if (type == 'SET_SERVO') _commands.add(CommandModel.setServo());
      if (type == 'WHILE') _commands.add(CommandModel.whileCmd());
      if (type == 'DELAY') _commands.add(CommandModel.delay());
      if (type == 'FOR') _commands.add(CommandModel.forCmd());
    });
  }

  void _run() async {
    if (_isRunning) {
      setState(() {
        _shouldStop = true;
        _isRunning = false;
      });
      return;
    }

    setState(() {
      _shouldStop = false;
      _isRunning = true;
    });

    Map<String, double> sensors = widget.valueGate;

    await executeCommands(
      _commands,
      sensors,
      _variables,
      (cmd, pin, val) {
        if (_shouldStop) return;
        debugPrint("SEND -> $pin := $val");
        List<int> value = [1, 1];
        switch (cmd) {
          case 1:
            value = [1, val.toInt()];
            break;
          case 2:
            value = [2, val.toInt()];
            break;
        }
        Map<String, List<int>> runData = {pin: value};
        widget.onDieuKhienChanged(runData);
      },
      stopFlag: () => _shouldStop,
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.red));
        }
      },
    );

    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _showTreeView() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Tổng quan lệnh (Outline)"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildTreeView(_commands, 0),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text("Đóng"))
          ],
        );
      },
    );
  }

  List<Widget> _buildTreeView(List<CommandModel> cmds, int depth) {
    final List<Widget> out = [];
    final indent = SizedBox(width: depth * 12.0);
    for (var cmd in cmds) {
      out.add(Row(children: [
        indent,
        Expanded(child: RichText(text: _buildSummarySpan(cmd))),
      ]));
      if (cmd.type == CommandType.ifCmd) {
        if (cmd.thenActions.isNotEmpty)
          out.add(Row(children: [
            SizedBox(width: (depth + 1) * 12.0),
            const Text('THEN:')
          ]));
        out.addAll(_buildTreeView(cmd.thenActions, depth + 1));
        if (cmd.elseActions.isNotEmpty) {
          out.add(Row(children: [
            SizedBox(width: (depth + 1) * 12.0),
            const Text('ELSE:')
          ]));
          out.addAll(_buildTreeView(cmd.elseActions, depth + 1));
        }
      } else if (cmd.type == CommandType.whileCmd) {
        if (cmd.thenActions.isNotEmpty)
          out.add(Row(children: [
            SizedBox(width: (depth + 1) * 12.0),
            const Text('DO:')
          ]));
        out.addAll(_buildTreeView(cmd.thenActions, depth + 1));
      } else if (cmd.type == CommandType.forCmd) {
        if (cmd.thenActions.isNotEmpty)
          out.add(Row(children: [
            SizedBox(width: (depth + 1) * 12.0),
            const Text('DO:')
          ]));
        out.addAll(_buildTreeView(cmd.thenActions, depth + 1));
      }
    }
    return out;
  }

  TextSpan _buildSummarySpan(CommandModel cmd) {
    Color typeColor;
    switch (cmd.type) {
      case CommandType.setCmd:
        typeColor = Colors.orange;
        break;
      case CommandType.setServoCmd:
        typeColor = Colors.teal;
        break;
      case CommandType.delayCmd:
        typeColor = Colors.purple;
        break;
      case CommandType.ifCmd:
        typeColor = Colors.blue;
        break;
      case CommandType.whileCmd:
        typeColor = Colors.green;
        break;
      case CommandType.forCmd:
        typeColor = Colors.brown;
        break;
    }

    // Helper to color tokens
    TextSpan tokensSpan(List<String> toks, List<String> extraVars) {
      final varsList = [..._variables.keys, ...extraVars];
      return TextSpan(
        children: toks.map((t) {
          if (varsList.contains(t)) {
            return TextSpan(
                text: '$t ', style: const TextStyle(color: Colors.indigo));
          } else if (_sensors.contains(t)) {
            return TextSpan(
                text: '$t ', style: const TextStyle(color: Colors.green));
          } else if (double.tryParse(t) != null) {
            return TextSpan(
                text: '$t ', style: const TextStyle(color: Colors.red));
          } else {
            return TextSpan(text: '$t ', style: const TextStyle());
          }
        }).toList(),
      );
    }

    // Build main span
    final children = <TextSpan>[];
    children.add(TextSpan(
        text: getCommandDisplayName(cmd.type),
        style: TextStyle(fontWeight: FontWeight.bold, color: typeColor)));
    children.add(const TextSpan(text: " "));

    if (cmd.type == CommandType.setCmd) {
      children.add(TextSpan(
          text: cmd.target, style: const TextStyle(color: Colors.deepOrange)));
      children.add(const TextSpan(text: " = "));
      children.add(tokensSpan(cmd.expressionTokens, []));
    } else if (cmd.type == CommandType.delayCmd) {
      children.add(TextSpan(
          text: "${cmd.delayMs}ms",
          style: const TextStyle(color: Colors.purple)));
    } else if (cmd.type == CommandType.setServoCmd) {
      children.add(TextSpan(
          text: cmd.target, style: const TextStyle(color: Colors.teal)));
      children.add(const TextSpan(text: " = "));
      children.add(tokensSpan(cmd.servoTokens, []));
      children.add(const TextSpan(text: "°"));
    } else if (cmd.type == CommandType.ifCmd) {
      children.add(TextSpan(
          text: cmd.conditions.map((c) => c.summary()).join(
              ' ${cmd.betweenOps.isNotEmpty ? cmd.betweenOps[0] : 'AND'} ')));
    } else if (cmd.type == CommandType.whileCmd) {
      children.add(TextSpan(
          text: cmd.conditions.map((c) => c.summary()).join(
              ' ${cmd.betweenOps.isNotEmpty ? cmd.betweenOps[0] : 'AND'} ')));
    } else if (cmd.type == CommandType.forCmd) {
      children.add(TextSpan(text: "${cmd.loopVar} = "));
      children.add(tokensSpan(cmd.initTokens, []));
      children.add(const TextSpan(text: "; "));
      children.add(tokensSpan(cmd.condLeftTokens, []));
      children.add(TextSpan(text: " ${cmd.condComparator} "));
      children.add(tokensSpan(cmd.condRightTokens, []));
      children.add(const TextSpan(text: "; "));
      children.add(TextSpan(text: "${cmd.loopVar} += "));
      children.add(tokensSpan(cmd.stepTokens, []));
    }

    return TextSpan(
        style: const TextStyle(fontSize: 14, color: Colors.black),
        children: children);
  }

  String getCommandDisplayName(CommandType type) {
    switch (type) {
      case CommandType.ifCmd:
        return "IF";
      case CommandType.setCmd:
        return "SET";
      case CommandType.delayCmd:
        return "DELAY";
      case CommandType.setServoCmd:
        return "SET SERVO";
      case CommandType.whileCmd:
        return "WHILE";
      case CommandType.forCmd:
        return "FOR";
    }
  }

  // move helpers unchanged
  void _moveUp(List<CommandModel> parent, CommandModel cmd) {
    final idx = parent.indexOf(cmd);
    if (idx > 0) {
      setState(() {
        parent.removeAt(idx);
        parent.insert(idx - 1, cmd);
      });
    }
  }

  void _moveDown(List<CommandModel> parent, CommandModel cmd) {
    final idx = parent.indexOf(cmd);
    if (idx >= 0 && idx < parent.length - 1) {
      setState(() {
        parent.removeAt(idx);
        parent.insert(idx + 1, cmd);
      });
    }
  }

  Widget _buildControls(CommandModel cmd, List<CommandModel> parent) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          iconSize: 18,
          tooltip: 'Move up',
          onPressed: () => _moveUp(parent, cmd),
          icon: const Icon(Icons.arrow_upward)),
      IconButton(
          iconSize: 18,
          tooltip: 'Move down',
          onPressed: () => _moveDown(parent, cmd),
          icon: const Icon(Icons.arrow_downward)),
      const SizedBox(width: 6),
      IconButton(
        iconSize: 20,
        tooltip: 'Xóa lệnh',
        onPressed: () {
          setState(() {
            parent.remove(cmd);
            cmd.dispose();
          });
        },
        icon: const Icon(Icons.delete, color: Colors.red),
      ),
    ]);
  }

  @override
  void dispose() {
    _varScrollController.dispose();
    for (var c in _commands) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Column(children: [
        Container(
            height: 28,
            width: double.infinity,
            color: Colors.blue.shade800,
            alignment: Alignment.center,
            child: const Text('Lệnh điều khiển',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // variables row
            SizedBox(
              height: 44,
              child: Scrollbar(
                controller: _varScrollController,
                thumbVisibility: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    final newOffset =
                        _varScrollController.offset - details.delta.dx;
                    if (!_varScrollController.hasClients) return;
                    final max = _varScrollController.position.maxScrollExtent;
                    if (newOffset < 0)
                      _varScrollController.jumpTo(0);
                    else if (newOffset > max)
                      _varScrollController.jumpTo(max);
                    else
                      _varScrollController.jumpTo(newOffset);
                  },
                  child: SingleChildScrollView(
                    controller: _varScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: ActionChip(
                              label: const Text("+ Var"),
                              onPressed: _addVariable)),
                      for (var v in _variables.keys)
                        Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Chip(
                                label: Text('$v=${_variables[v]}'),
                                onDeleted: () =>
                                    setState(() => _variables.remove(v)))),
                      const SizedBox(width: 8),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                ElevatedButton.icon(
                  onPressed: _showTreeView,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Xem tổng thể'),
                ),
                PopupMenuButton<String>(
                  onSelected: _addCommand,
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'SET', child: Text("Thêm SET")),
                    PopupMenuItem(
                        value: 'SET_SERVO', child: Text("Thêm SET SERVO")),
                    PopupMenuItem(value: 'IF', child: Text("Thêm IF")),
                    PopupMenuItem(value: 'WHILE', child: Text("Thêm WHILE")),
                    PopupMenuItem(value: 'DELAY', child: Text("Thêm DELAY")),
                    PopupMenuItem(value: 'FOR', child: Text("Thêm FOR")),
                  ],
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("Thêm lệnh",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: null,
                  ),
                ),
                // RUN
                ElevatedButton.icon(
                  onPressed: _run,
                  icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow, size: 16),
                  label: Text(_isRunning ? 'STOP' : 'RUN', style: const TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                // SAVE
                ElevatedButton.icon(
                  onPressed: _saveProgram,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                // OPEN
                ElevatedButton.icon(
                  onPressed: _openProgram,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Open', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _commands.length,
            itemBuilder: (ctx, i) {
              final cmd = _commands[i];
              return KeyedSubtree(
                  key: ValueKey(cmd.id),
                  child: _buildCommandTile(cmd, _commands));
            },
          ),
        ),
      ]),
    );
  }

  // NOTE: add optional extraVars parameter so nested rendering can include loopVar
  Widget _buildCommandTile(CommandModel cmd, List<CommandModel> parent,
      [List<String>? extraVars]) {
    final controls = _buildControls(cmd, parent);
    final availableVars = [
      ..._variables.keys,
      ...(extraVars ?? [])
    ]; // *** use this for ExpressionBuilder

    if (cmd.type == CommandType.setCmd) {
      return _buildBlock(
        color: Colors.orange,
        title: "SET",
        controls: controls,
        child: Row(children: [
          DropdownButton<String>(
            value: cmd.target,
            items: [..._dPins, ..._variables.keys]
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => cmd.target = v ?? 'D3'),
          ),
          const SizedBox(width: 8),
          const Text("=",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
              child: ExpressionBuilder(
                  tokens: cmd.expressionTokens,
                  sensors: _sensors,
                  variables: availableVars.cast<String>())),
        ]),
      );
    } else if (cmd.type == CommandType.delayCmd) {
      return _buildBlock(
        color: Colors.purple,
        title: "DELAY",
        controls: controls,
        child: Row(children: [
          SizedBox(
            width: 80,
            child: TextField(
              controller: TextEditingController(text: cmd.delayMs.toString()),
              onChanged: (v) =>
                  setState(() => cmd.delayMs = int.tryParse(v) ?? cmd.delayMs),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),
          const Text("ms"),
        ]),
      );
    } else if (cmd.type == CommandType.setServoCmd) {
      return _buildBlock(
        color: Colors.teal,
        title: "SET SERVO",
        controls: controls,
        child: Row(children: [
          DropdownButton<String>(
            value: cmd.target,
            items: _dPins
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => cmd.target = v ?? 'D3'),
          ),
          const SizedBox(width: 8),
          const Text("=",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
              child: ExpressionBuilder(
                  tokens: cmd.servoTokens,
                  sensors: _sensors,
                  variables: availableVars.cast<String>())),
          const SizedBox(width: 6),
          const Text("°"),
        ]),
      );
    } else if (cmd.type == CommandType.whileCmd) {
      // propagate extraVars to nested children (so if outer extraVars exists it continues)
      return _buildBlock(
        color: Colors.green,
        title: "WHILE",
        controls: controls,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (int i = 0; i < cmd.conditions.length; i++)
            _buildConditionRow(cmd, i, availableVars.cast<String>()),
          const SizedBox(height: 6),
          ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  cmd.conditions.add(Condition());
                  if (cmd.conditions.length > 1) cmd.betweenOps.add('AND');
                });
              },
              icon: const Icon(Icons.add),
              label: const Text("Thêm điều kiện")),
          const Divider(),
          const Text("DO:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Column(children: [
            for (int i = 0; i < cmd.thenActions.length; i++)
              KeyedSubtree(
                  key: ValueKey(cmd.thenActions[i].id),
                  child: _buildCommandTile(
                      cmd.thenActions[i], cmd.thenActions, extraVars)),
          ]),
          const SizedBox(height: 6),
          PopupMenuButton<String>(
            onSelected: (choice) {
              setState(() {
                if (choice == 'SET') cmd.thenActions.add(CommandModel.set());
                if (choice == 'SET_SERVO')
                  cmd.thenActions.add(CommandModel.setServo());
                if (choice == 'IF') cmd.thenActions.add(CommandModel.ifCmd());
                if (choice == 'WHILE')
                  cmd.thenActions.add(CommandModel.whileCmd());
                if (choice == 'DELAY')
                  cmd.thenActions.add(CommandModel.delay());
                if (choice == 'FOR') cmd.thenActions.add(CommandModel.forCmd());
              });
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'SET', child: Text("Thêm SET")),
              PopupMenuItem(value: 'SET_SERVO', child: Text("Thêm SET SERVO")),
              PopupMenuItem(value: 'IF', child: Text("Thêm IF")),
              PopupMenuItem(value: 'WHILE', child: Text("Thêm WHILE")),
              PopupMenuItem(value: 'DELAY', child: Text("Thêm DELAY")),
              PopupMenuItem(value: 'FOR', child: Text("Thêm FOR")),
            ],
            child: const TextButton(
                child: Text("Thêm hành động DO"), onPressed: null),
          ),
        ]),
      );
    } else if (cmd.type == CommandType.forCmd) {
      // FOR: we must ensure body sees loopVar as local variable
      final childExtraVars = [
        ...(extraVars ?? []),
        cmd.loopVar
      ]; // *** pass loopVar to children
      return _buildBlock(
        color: Colors.brown,
        title: "FOR",
        controls: _buildControls(cmd, parent),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
                width: 120,
                child: TextField(
                    controller: TextEditingController(text: cmd.loopVar),
                    onChanged: (v) => setState(
                        () => cmd.loopVar = v.trim().isEmpty ? 'i' : v.trim()),
                    decoration: const InputDecoration(labelText: "Biến"))),
            const SizedBox(width: 8),
            const Text("="),
            const SizedBox(width: 8),
            Expanded(
                child: ExpressionBuilder(
                    tokens: cmd.initTokens,
                    sensors: _sensors,
                    variables: availableVars.cast<String>())),
            // init shouldn't need the loopVar itself
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Text("Condition:"),
            const SizedBox(width: 8),
            Expanded(
                child: ExpressionBuilder(
                    tokens: cmd.condLeftTokens,
                    sensors: _sensors,
                    variables: [...availableVars, cmd.loopVar])),
            // left can use loopVar
            const SizedBox(width: 8),
            DropdownButton<String>(
                value: cmd.condComparator,
                items: ['<', '>', '==', '!=', '<=', '>=']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => cmd.condComparator = v ?? '<')),
            const SizedBox(width: 8),
            Expanded(
                child: ExpressionBuilder(
                    tokens: cmd.condRightTokens,
                    sensors: _sensors,
                    variables: availableVars.cast<String>())),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Text("STEP (increment):"),
            const SizedBox(width: 8),
            Expanded(
                child: ExpressionBuilder(
                    tokens: cmd.stepTokens,
                    sensors: _sensors,
                    variables: [...availableVars, cmd.loopVar])),
          ]),
          const SizedBox(height: 8),
          const Divider(),
          const Text("DO:", style: TextStyle(fontWeight: FontWeight.bold)),
          Column(children: [
            for (int i = 0; i < cmd.thenActions.length; i++)
              KeyedSubtree(
                  key: ValueKey(cmd.thenActions[i].id),
                  child: _buildCommandTile(cmd.thenActions[i], cmd.thenActions,
                      childExtraVars.cast<String>())),
            // *** pass childExtraVars (contains loopVar)
          ]),
          PopupMenuButton<String>(
            onSelected: (choice) {
              setState(() {
                if (choice == 'SET') cmd.thenActions.add(CommandModel.set());
                if (choice == 'SET_SERVO')
                  cmd.thenActions.add(CommandModel.setServo());
                if (choice == 'IF') cmd.thenActions.add(CommandModel.ifCmd());
                if (choice == 'WHILE')
                  cmd.thenActions.add(CommandModel.whileCmd());
                if (choice == 'DELAY')
                  cmd.thenActions.add(CommandModel.delay());
                if (choice == 'FOR') cmd.thenActions.add(CommandModel.forCmd());
              });
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'SET', child: Text("Thêm SET")),
              PopupMenuItem(value: 'SET_SERVO', child: Text("Thêm SET SERVO")),
              PopupMenuItem(value: 'IF', child: Text("Thêm IF")),
              PopupMenuItem(value: 'WHILE', child: Text("Thêm WHILE")),
              PopupMenuItem(value: 'DELAY', child: Text("Thêm DELAY")),
              PopupMenuItem(value: 'FOR', child: Text("Thêm FOR")),
            ],
            child: const TextButton(
                child: Text("Thêm hành động DO"), onPressed: null),
          ),
        ]),
      );
    } else {
      // IF
      return _buildBlock(
        color: Colors.blue,
        title: "IF",
        controls: controls,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (int i = 0; i < cmd.conditions.length; i++)
            _buildConditionRow(cmd, i, availableVars.cast<String>()),
          const SizedBox(height: 6),
          ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  cmd.conditions.add(Condition());
                  if (cmd.conditions.length > 1) cmd.betweenOps.add('AND');
                });
              },
              icon: const Icon(Icons.add),
              label: const Text("Thêm điều kiện")),
          const Divider(),
          const Text("THEN:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Column(children: [
            for (int i = 0; i < cmd.thenActions.length; i++)
              KeyedSubtree(
                  key: ValueKey(cmd.thenActions[i].id),
                  child: _buildCommandTile(
                      cmd.thenActions[i], cmd.thenActions, extraVars)),
          ]),
          const SizedBox(height: 6),
          PopupMenuButton<String>(
            onSelected: (choice) {
              setState(() {
                if (choice == 'SET') cmd.thenActions.add(CommandModel.set());
                if (choice == 'IF') cmd.thenActions.add(CommandModel.ifCmd());
                if (choice == 'DELAY')
                  cmd.thenActions.add(CommandModel.delay());
                if (choice == 'SET_SERVO')
                  cmd.thenActions.add(CommandModel.setServo());
                if (choice == 'WHILE')
                  cmd.thenActions.add(CommandModel.whileCmd());
                if (choice == 'FOR') cmd.thenActions.add(CommandModel.forCmd());
              });
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'SET', child: Text("Thêm SET")),
              PopupMenuItem(value: 'SET_SERVO', child: Text("Thêm SET SERVO")),
              PopupMenuItem(value: 'IF', child: Text("Thêm IF")),
              PopupMenuItem(value: 'WHILE', child: Text("Thêm WHILE")),
              PopupMenuItem(value: 'DELAY', child: Text("Thêm DELAY")),
              PopupMenuItem(value: 'FOR', child: Text("Thêm FOR")),
            ],
            child: const TextButton(
                child: Text("Thêm hành động THEN"), onPressed: null),
          ),
          const Divider(),
          if (cmd.elseActions.isNotEmpty) ...[
            const Text("ELSE:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Column(children: [
              for (int i = 0; i < cmd.elseActions.length; i++)
                KeyedSubtree(
                    key: ValueKey(cmd.elseActions[i].id),
                    child: _buildCommandTile(
                        cmd.elseActions[i], cmd.elseActions, extraVars)),
            ]),
            const SizedBox(height: 6),
            PopupMenuButton<String>(
              onSelected: (choice) {
                setState(() {
                  if (choice == 'SET') cmd.elseActions.add(CommandModel.set());
                  if (choice == 'IF') cmd.elseActions.add(CommandModel.ifCmd());
                  if (choice == 'DELAY')
                    cmd.elseActions.add(CommandModel.delay());
                  if (choice == 'SET_SERVO')
                    cmd.elseActions.add(CommandModel.setServo());
                  if (choice == 'WHILE')
                    cmd.elseActions.add(CommandModel.whileCmd());
                  if (choice == 'FOR')
                    cmd.thenActions.add(CommandModel.forCmd());
                });
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'SET', child: Text("Thêm SET")),
                PopupMenuItem(
                    value: 'SET_SERVO', child: Text("Thêm SET SERVO")),
                PopupMenuItem(value: 'IF', child: Text("Thêm IF")),
                PopupMenuItem(value: 'WHILE', child: Text("Thêm WHILE")),
                PopupMenuItem(value: 'DELAY', child: Text("Thêm DELAY")),
                PopupMenuItem(value: 'FOR', child: Text("Thêm FOR")),
              ],
              child: const TextButton(
                  child: Text("Thêm hành động ELSE"), onPressed: null),
            ),
          ] else
            TextButton(
              onPressed: () {
                setState(() {
                  cmd.elseActions = [];
                  cmd.elseActions.add(CommandModel.set());
                });
              },
              child: const Text("Thêm ELSE"),
            ),
        ]),
      );
    }
  }

  // Updated _buildConditionRow to accept availableVars (so it can include loopVar)
  Widget _buildConditionRow(
      CommandModel cmd, int i, List<String> availableVars) {
    Condition cond = cmd.conditions[i];
    return Column(children: [
      Row(children: [
        Expanded(
            child: ExpressionBuilder(
                tokens: cond.leftTokens,
                sensors: _sensors,
                variables: availableVars)),
        const SizedBox(width: 8),
        DropdownButton<String>(
            value: cond.comparator,
            items: ['>', '<', '==', '!=', '>=', '<=']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) =>
                setState(() => cond.comparator = v ?? cond.comparator)),
        const SizedBox(width: 8),
        Expanded(
            child: ExpressionBuilder(
                tokens: cond.rightTokens,
                sensors: _sensors,
                variables: availableVars)),
        const Spacer(),
        IconButton(
            onPressed: () {
              setState(() {
                if (cmd.conditions.length > 1) {
                  cmd.conditions.removeAt(i);
                  if (cmd.betweenOps.length >= cmd.conditions.length)
                    cmd.betweenOps =
                        List<String>.filled(cmd.conditions.length - 1, 'AND');
                }
              });
            },
            icon: const Icon(Icons.delete, color: Colors.red)),
      ]),
      if (i < cmd.conditions.length - 1)
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: DropdownButton<String>(
            value: (i < cmd.betweenOps.length) ? cmd.betweenOps[i] : 'AND',
            items: ['AND', 'OR']
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) {
              setState(() {
                if (i < cmd.betweenOps.length)
                  cmd.betweenOps[i] = v ?? cmd.betweenOps[i];
                else {
                  while (cmd.betweenOps.length < cmd.conditions.length - 1)
                    cmd.betweenOps.add('AND');
                  cmd.betweenOps[i] = v ?? 'AND';
                }
              });
            },
          ),
        ),
    ]);
  }

  Widget _buildBlock(
      {required Color color,
      required String title,
      required Widget child,
      required Widget controls}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const Spacer(),
          controls
        ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }

  Future<void> _openProgram() async {
    try {
      // 1. Chọn file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Mở chương trình',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();
        final data = jsonDecode(jsonStr);

        // 2. Deserialize
        final Map<String, double> loadedVars = (data['variables'] as Map)
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
        final List<CommandModel> loadedCmds = (data['commands'] as List)
            .map((c) => CommandModel.fromJson(c))
            .toList();

        // 3. Cập nhật state
        setState(() {
          _variables.clear();
          _variables.addAll(loadedVars);
          _commands.clear();
          _commands.addAll(loadedCmds);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đã mở chương trình")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Lỗi khi mở: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveProgram() async {
    try {
      // 1. Serialize ra JSON
      final jsonData = jsonEncode({
        'variables': _variables,
        'commands': _commands.map((c) => c.toJson()).toList(),
      });

      // 2. Chọn nơi lưu file
      String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Chọn nơi lưu chương trình',
        fileName: 'program.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (path != null) {
        final file = File(path);
        await file.writeAsString(jsonData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đã lưu chương trình")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Lỗi khi lưu: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ================= Expression Builder =================

class ExpressionBuilder extends StatefulWidget {
  final List<String> tokens;
  final List<String> sensors;
  final List<String> variables;

  const ExpressionBuilder(
      {super.key,
      required this.tokens,
      required this.sensors,
      required this.variables});

  @override
  State<ExpressionBuilder> createState() => _ExpressionBuilderState();
}

class _ExpressionBuilderState extends State<ExpressionBuilder> {
  void _addOperand(String token) {
    setState(() {
      if (widget.tokens.isNotEmpty && _isOperand(widget.tokens.last)) {
        widget.tokens.add('+');
      }
      widget.tokens.add(token);
    });
  }

  bool _isOperand(String t) {
    return !(t == '+' ||
        t == '-' ||
        t == '*' ||
        t == '/' ||
        t == '%' ||
        t == 'abs' ||
        t == '(' ||
        t == ')');
  }

  void _addOperator(String op) {
    setState(() {
      if (widget.tokens.isEmpty) return;
      if (widget.tokens.last == '+' || widget.tokens.last == '-') return;
      widget.tokens.add(op);
    });
  }

  void _clear() => setState(() => widget.tokens.clear());

  @override
  Widget build(BuildContext context) {
    return Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6)),
              child:
                  Text(widget.tokens.isEmpty ? '0' : widget.tokens.join(' '))),
          PopupMenuButton<String>(
            onSelected: (o) {
              if (o == 'INPUT_NUMBER') {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    final ctrl = TextEditingController();
                    return AlertDialog(
                      title: const Text("Nhập số"),
                      content: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(hintText: "Ví dụ: 10")),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Hủy")),
                        TextButton(
                            onPressed: () {
                              final val = ctrl.text.trim();
                              if (val.isNotEmpty) {
                                setState(() {
                                  _addOperand(val);
                                });
                              }
                              Navigator.pop(ctx);
                            },
                            child: const Text("OK")),
                      ],
                    );
                  },
                );
              } else {
                _addOperand(o);
              }
            },
            itemBuilder: (ctx) => [
              ...widget.sensors
                  .map((s) => PopupMenuItem(value: s, child: Text(s))),
              ...widget.variables
                  .map((v) => PopupMenuItem(value: v, child: Text(v))),
              const PopupMenuItem(value: '0', child: Text("0")),
              const PopupMenuItem(value: '1', child: Text("1")),
              const PopupMenuItem(
                  value: 'INPUT_NUMBER', child: Text("Nhập số...")),
            ],
            child: const Icon(Icons.add_circle, color: Colors.green),
          ),
          PopupMenuButton<String>(
            onSelected: _addOperator,
            itemBuilder: (ctx) => ['+', '-', '*', '/', '%', 'abs']
                .map((o) => PopupMenuItem(value: o, child: Text(o)))
                .toList(),
            child: const Icon(Icons.calculate, color: Colors.blue),
          ),
          IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.clear, color: Colors.red)),
        ]);
  }
}
