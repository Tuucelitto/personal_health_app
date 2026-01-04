class MacroTargets {
  final double proteinPerc;
  final double carbsPerc;
  final double fatPerc;

  MacroTargets({
    required this.proteinPerc,
    required this.carbsPerc,
    required this.fatPerc,
  });

  factory MacroTargets.fromJson(Map<String, dynamic> json) {
    return MacroTargets(
      proteinPerc: (json['protein_perc'] as num?)?.toDouble() ?? 0.0,
      carbsPerc: (json['carbs_perc'] as num?)?.toDouble() ?? 0.0,
      fatPerc: (json['fat_perc'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'protein_perc': proteinPerc,
      'carbs_perc': carbsPerc,
      'fat_perc': fatPerc,
    };
  }
}

class CalculationResult {
  final double bmi;
  final String bmiCategory;
  final double bmr;
  final double tdee;
  final double targetCalories;
  final MacroTargets targetMacros;
  final List<dynamic> recommendedRecipes;
  final List<dynamic> recommendedExercises;
  final Map<String, dynamic> weeklyPlan;

  CalculationResult({
    required this.bmi,
    required this.bmiCategory,
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.targetMacros,
    required this.recommendedRecipes,
    required this.recommendedExercises,
    required this.weeklyPlan,
  });

  Map<String, dynamic> toMap() {
    return {
      'bmi': bmi,
      'bmi_category': bmiCategory,
      'bmr': bmr,
      'tdee': tdee,
      'target_calories': targetCalories,
      'target_macros': targetMacros.toMap(),
      'recommended_recipes': recommendedRecipes,
      'recommended_exercises': recommendedExercises,
      'weekly_plan': weeklyPlan,
      'save_date': DateTime.now().toIso8601String(),
    };
  }

  factory CalculationResult.fromJson(Map<String, dynamic> json) {
    final rawWeeklyPlan = json['weekly_plan'];

    Map<String, dynamic> extractedWeeklyPlan = {};

    if (rawWeeklyPlan != null && rawWeeklyPlan is Map<String, dynamic>) {
      print('DEBUG: rawWeeklyPlan anahtarları: ${rawWeeklyPlan.keys.toList()}');

      dynamic currentPlan = rawWeeklyPlan;
      final dayNames = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"];

      int maxIterations = 10;
      while (currentPlan is Map<String, dynamic> && maxIterations > 0) {
        final currentMap = currentPlan as Map<String, dynamic>;
        final currentKeys = currentMap.keys.toList();

        final hasDayName = currentKeys.any((key) => dayNames.contains(key));
        if (hasDayName) {
          break;
        }

        String? planKey;
        for (final key in currentKeys) {
          if (key.toString().toLowerCase().contains('plan')) {
            planKey = key;
            break;
          }
        }

        if (planKey != null && currentMap[planKey] is Map<String, dynamic>) {
          currentPlan = currentMap[planKey];
          maxIterations--;
        } else if (currentKeys.length == 1 && currentMap[currentKeys.first] is Map<String, dynamic>) {
          currentPlan = currentMap[currentKeys.first];
          maxIterations--;
        } else {
          break;
        }
      }

      if (currentPlan is Map<String, dynamic>) {
        extractedWeeklyPlan = Map<String, dynamic>.from(currentPlan);
      }
    }

    return CalculationResult(
      bmi: (json['bmi'] as num?)?.toDouble() ?? 0.0,
      bmiCategory: json['bmi_category'] ?? 'Bilinmiyor',
      bmr: (json['bmr'] as num?)?.toDouble() ?? 0.0,
      tdee: (json['tdee'] as num?)?.toDouble() ?? 0.0,
      targetCalories: (json['target_calories'] as num?)?.toDouble() ?? 0.0,
      targetMacros: json['target_macros'] != null
          ? MacroTargets.fromJson(json['target_macros'])
          : MacroTargets(proteinPerc: 0.0, carbsPerc: 0.0, fatPerc: 0.0),
      recommendedRecipes: json['recommended_recipes'] ?? [],
      recommendedExercises: json['recommended_exercises'] ?? [],
      weeklyPlan: extractedWeeklyPlan,
    );
  }
}