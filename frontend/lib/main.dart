import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'log_in.dart';
import 'main_container.dart';
import 'data_models.dart';
import 'weekly_plan_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
  runApp(const HealthApp());
}

// --- 1. ANA UYGULAMA YAPISI ---

class HealthApp extends StatefulWidget {
  const HealthApp({super.key});

  @override
  State<HealthApp> createState() => HealthAppState();
}

class HealthAppState extends State<HealthApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitPlan Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF673AB7),
          primary: const Color(0xFF673AB7),
          secondary: const Color(0xFF00BCD4),
          background: Colors.white,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasData) {
            return const MainContainer();
          } else {
            return const LoginPage();
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- 2. SUMMARY PAGE ---

class SummaryPage extends StatelessWidget {
  final CalculationResult result;

  const SummaryPage({super.key, required this.result});

  Widget _buildInfoCard(
      BuildContext context, {
        required String title,
        required List<Widget> children,
        required Color color,
        IconData? icon,
      }) {
    final primaryColor = Theme.of(context).primaryColor;

    return Card(
      color: color,
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) Icon(icon, color: primaryColor, size: 28),
                if (icon != null) const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    String goalText = "Kilo Koruma";
    if (result.targetCalories < result.tdee - 100) {
      goalText = "Kilo Verme";
    } else if (result.targetCalories > result.tdee + 100) {
      goalText = "Kilo Alma / Kas Kazanımı";
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Plan Özeti"),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BMI & BMR Kartı
            _buildInfoCard(
              context,
              title: "Temel Sağlık Ölçütleriniz",
              icon: Icons.monitor_weight,
              color: Colors.white,
              children: [
                Text(
                    "Vücut Kitle İndeksi (BMI): ${result.bmi.toStringAsFixed(1)} (${result.bmiCategory})"),
                Text("Bazal Metabolizma Hızı (BMR): ${result.bmr} kcal"),
              ],
            ),

            // Kalori Hedefi Kartı
            _buildInfoCard(
              context,
              title: "Günlük Kalori Hedefiniz",
              icon: Icons.local_fire_department,
              color: primaryColor.withOpacity(0.1),
              children: [
                Text("TDEE: ${result.tdee} kcal",
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  "${result.targetCalories} kcal",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
                Text("Plan Hedefi: $goalText"),
              ],
            ),

            // Makro Kartı
            _buildInfoCard(
              context,
              title: "Makro Besin Dağılımı",
              icon: Icons.pie_chart,
              color: Colors.white,
              children: [
                Text(
                    "Protein: ${(result.targetMacros.proteinPerc * 100).toStringAsFixed(0)}%"),
                Text(
                    "Karbonhidrat: ${(result.targetMacros.carbsPerc * 100).toStringAsFixed(0)}%"),
                Text(
                    "Yağ: ${(result.targetMacros.fatPerc * 100).toStringAsFixed(0)}%"),
              ],
            ),

            const SizedBox(height: 30),

            // --- Haftalık Plan Butonu ---
            ElevatedButton(
              onPressed: () {
                final planToPass = result.weeklyPlan.isNotEmpty 
                    ? result.weeklyPlan 
                    : <String, dynamic>{};
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WeeklyPlanPage(
                      weeklyPlan: planToPass,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
              child: const Text(
                "Haftalık Planı Göster",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
