import 'dart:math';
import 'package:math_expressions/math_expressions.dart';

class ExcelFormulaEngine {
  /// Parses and evaluates spreadsheet formulas.
  static double evaluate(String rawFormula, Map<String, double> cellVariables) {
    try {
      String formula = rawFormula.trim();
      if (formula.startsWith('=')) {
        formula = formula.substring(1).trim();
      }

      
      final sumRegex = RegExp(r'SUM\(([^)]+)\)', caseSensitive: false);
      formula = formula.replaceAllMapped(sumRegex, (match) {
        final inner = match.group(1) ?? '';
        final tokens = inner.split(RegExp(r'[,+]'));
        double total = 0.0;
        for (var token in tokens) {
          final clean = token.trim();
          total += cellVariables[clean] ?? double.tryParse(clean) ?? 0.0;
        }
        return total.toString();
      });

      
      final avgRegex = RegExp(r'AVERAGE\(([^)]+)\)', caseSensitive: false);
      formula = formula.replaceAllMapped(avgRegex, (match) {
        final inner = match.group(1) ?? '';
        final tokens = inner.split(RegExp(r'[,+]'));
        double total = 0.0;
        int count = 0;
        for (var token in tokens) {
          final clean = token.trim();
          total += cellVariables[clean] ?? double.tryParse(clean) ?? 0.0;
          count++;
        }
        return count > 0 ? (total / count).toString() : "0";
      });

      
      final roundRegex = RegExp(r'ROUND\(([^)]+)\)', caseSensitive: false);
      while (roundRegex.hasMatch(formula)) {
        formula = formula.replaceAllMapped(roundRegex, (match) {
          final inner = match.group(1) ?? '';
          final parts = inner.split(',');
          double val = evaluate(parts[0], cellVariables);
          int places = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
          num mod = pow(10.0, places);
          return ((val * mod).round() / mod).toString();
        });
      }

      
      cellVariables.forEach((key, val) {
        formula = formula.replaceAll(key, val.toString());
      });

      
      GrammarParser p = GrammarParser();
      Expression exp = p.parse(formula);
      ContextModel cm = ContextModel();
      return exp.evaluate(EvaluationType.REAL, cm);
    } catch (e) {
      return 0.0;
    }
  }
}