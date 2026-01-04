import 'package:flutter/material.dart';

class WeeklyPlanPage extends StatefulWidget {
  final Map<String, dynamic> weeklyPlan;

  const WeeklyPlanPage({super.key, required this.weeklyPlan});

  @override
  State<WeeklyPlanPage> createState() => _WeeklyPlanPageState();
}

class _WeeklyPlanPageState extends State<WeeklyPlanPage> {
  final Set<String> _expandedDays = <String>{};

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    final dayNames = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"];
    final englishDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

    dynamic currentPlan = widget.weeklyPlan;
    int maxIterations = 10;
    
    while (currentPlan is Map<String, dynamic> && maxIterations > 0) {
      final currentMap = currentPlan as Map<String, dynamic>;
      final currentKeys = currentMap.keys.toList();
      
      final hasDayName = currentKeys.any((key) => dayNames.contains(key));
      if (hasDayName) break;
      
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
    
    final plan = (currentPlan is Map<String, dynamic>) 
        ? Map<String, dynamic>.from(currentPlan)
        : <String, dynamic>{};

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
        title: const Text("Haftalık Plan"),
          centerTitle: true,
        backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık kartı
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    "7 Günlük Beslenme ve Egzersiz Planı",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Her günü tıklayarak detayları görüntüleyin",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Günler listesi
            ...dayNames.asMap().entries.map((entry) {
              final index = entry.key;
              final turkishDay = entry.value;
              final englishDay = index < englishDays.length ? englishDays[index] : null;

              dynamic dayData;
              if (plan.containsKey(turkishDay)) {
                dayData = plan[turkishDay];
              } else if (englishDay != null && plan.containsKey(englishDay)) {
                dayData = plan[englishDay];
              } else if (index < plan.keys.length) {
                dayData = plan.values.elementAt(index);
              }
              
              final data = (dayData != null && dayData is Map<String, dynamic>)
                  ? Map<String, dynamic>.from(dayData as Map<String, dynamic>)
                  : <String, dynamic>{};

              final dayInfo = _extractDayInfo(data);
              final isExpanded = _expandedDays.contains(turkishDay);
              
              return _buildDayCard(
                context: context,
                dayName: turkishDay,
                dayNumber: index + 1,
                isExpanded: isExpanded,
                dayInfo: dayInfo,
                primaryColor: primaryColor,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  DayInfo _extractDayInfo(Map<String, dynamic> data) {
    Map<String, dynamic> meals = <String, dynamic>{};
    String? mealsKey;
    
    List<String> mapKeys = [];
    for (final key in data.keys) {
      if (data[key] is Map<String, dynamic>) {
        mapKeys.add(key.toString());
      }
    }
    
    for (final mapKey in mapKeys) {
      final keyLower = mapKey.toLowerCase();
      if (!keyLower.contains("egzersiz") && !keyLower.contains("exercise")) {
        mealsKey = mapKey;
        break;
      }
    }
    
    if (mealsKey != null && data[mealsKey] is Map<String, dynamic>) {
      meals = Map<String, dynamic>.from(data[mealsKey] as Map<String, dynamic>);
    }

    final mealEntries = meals.entries.toList();
    String? breakfast, lunch, dinner;
    
    if (mealEntries.isNotEmpty) breakfast = mealEntries[0].value?.toString();
    if (mealEntries.length > 1) lunch = mealEntries[1].value?.toString();
    if (mealEntries.length > 2) dinner = mealEntries[2].value?.toString();

    String exercise = "Egzersiz yok";
    Map<String, List<String>> movements = {};

    for (final key in data.keys) {
      final keyStr = key.toString().toLowerCase();
      if (keyStr.contains("hareketler") || keyStr.contains("movements")) {
        final movementsValue = data[key];
        if (movementsValue is List) {
          final movementList = (movementsValue as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList();
          if (movementList.isNotEmpty) {
            movements["Önerilen Hareketler"] = movementList;
          }
        } else if (movementsValue is Map<String, dynamic>) {
          final movementsMap = movementsValue as Map<String, dynamic>;
          for (final entry in movementsMap.entries) {
            if (entry.value is List) {
              movements[entry.key] = (entry.value as List)
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList();
            } else if (entry.value is String) {
              final items = entry.value.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              if (items.isNotEmpty) {
                movements[entry.key] = items;
              }
            }
          }
        }
      }
    }

    for (final key in data.keys) {
      final keyStr = key.toString().toLowerCase();
      if (keyStr.contains("egzersiz") || keyStr.contains("exercise")) {
        final exerciseValue = data[key]?.toString() ?? "Egzersiz yok";
        if (exerciseValue.contains("Hareketler:")) {
          exercise = exerciseValue.split("Hareketler:")[0].trim();
        } else {
          exercise = exerciseValue;
        }
        break;
      }
    }
    
    return DayInfo(
      breakfast: breakfast ?? "Belirtilmemiş",
      lunch: lunch ?? "Belirtilmemiş",
      dinner: dinner ?? "Belirtilmemiş",
      exercise: exercise,
      movements: movements,
    );
  }

  Widget _buildDayCard({
    required BuildContext context,
    required String dayName,
    required int dayNumber,
    required bool isExpanded,
    required DayInfo dayInfo,
    required Color primaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                "$dayNumber",
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: Text(
            dayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            color: primaryColor,
            size: 28,
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedDays.add(dayName);
              } else {
                _expandedDays.remove(dayName);
              }
            });
          },
          children: [
            const SizedBox(height: 8),
            _buildMealsCard(dayInfo, primaryColor),
            const SizedBox(height: 12),
            _buildExerciseCard(dayInfo, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMealsCard(DayInfo dayInfo, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant, color: Colors.orange.shade700, size: 24),
              const SizedBox(width: 8),
              const Text(
                "Öğünler",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMealItem("🥞", "Kahvaltı", dayInfo.breakfast),
          const SizedBox(height: 12),
          _buildMealItem("🥗", "Öğle", dayInfo.lunch),
          const SizedBox(height: 12),
          _buildMealItem("🍽️", "Akşam", dayInfo.dinner),
        ],
      ),
    );
  }

  Widget _buildMealItem(String emoji, String mealType, String mealName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mealType, style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mealName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(DayInfo dayInfo, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 8),
              const Text(
                "Egzersiz",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dayInfo.exercise.split("Hareketler:")[0].trim(),
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (dayInfo.movements.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "💪 Hareket Önerileri",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...dayInfo.movements.entries.map((entry) {
              return _buildMovementSection(entry.key, entry.value);
            }).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildMovementSection(String category, List<String> movements) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category != "Önerilen Hareketler")
            Text(
              category,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          if (category != "Önerilen Hareketler") const SizedBox(height: 8),
          ...movements.map((movement) {
            return Padding(
              padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.fitness_center, size: 16, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      movement,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class DayInfo {
  final String breakfast;
  final String lunch;
  final String dinner;
  final String exercise;
  final Map<String, List<String>> movements;

  DayInfo({
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.exercise,
    this.movements = const {},
  });
}
