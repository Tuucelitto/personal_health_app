import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'goal_activity.dart';
import 'main.dart';
import 'data_models.dart';

class BodyDataPage extends StatefulWidget {
  const BodyDataPage({super.key});

  @override
  State<BodyDataPage> createState() => _BodyDataPageState();
}

class _BodyDataPageState extends State<BodyDataPage> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  String _sex = "male";

  bool _isLoadingLastPlan = false;

  Future<void> _loadLastPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoadingLastPlan = true);

    const String appId = "fitplan-pro-v1";

    try {
      final doc = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('users')
          .doc(user.uid)
          .collection('user_plans')
          .doc('latest_plan')
          .get();

      if (doc.exists && doc.data() != null) {
        final result = CalculationResult.fromJson(doc.data()!);

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SummaryPage(result: result)),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Henüz kaydedilmiş bir planınız bulunmuyor.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Plan yüklenirken bir hata oluştu: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoadingLastPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("1. Adım: Beden Verileri"),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _isLoadingLastPlan
                  ? const Center(child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ))
                  : OutlinedButton.icon(
                onPressed: _loadLastPlan,
                icon: const Icon(Icons.history_rounded),
                label: const Text("SON PLANIMI GÖRÜNTÜLE", style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 25),
              const Center(
                child: Text(
                  "Veya yeni bir plan oluşturmak için verilerinizi girin:",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 20),

              _buildInputCard(
                children: [
                  _buildNumericField(_weightController, "Ağırlık (kg)", Icons.scale),
                  const SizedBox(height: 15),
                  _buildNumericField(_heightController, "Boy (cm)", Icons.height),
                  const SizedBox(height: 15),
                  _buildNumericField(_ageController, "Yaş", Icons.calendar_today),
                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    value: _sex,
                    items: const [
                      DropdownMenuItem(value: "male", child: Text("Erkek")),
                      DropdownMenuItem(value: "female", child: Text("Kadın")),
                    ],
                    onChanged: (val) => setState(() => _sex = val!),
                    decoration: InputDecoration(
                      labelText: "Cinsiyet",
                      prefixIcon: Icon(Icons.person, color: primaryColor.withOpacity(0.7)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _navigateToGoalPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 8,
                ),
                child: const Text("DEVAM ET (2. Adım)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({required List<Widget> children}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildNumericField(TextEditingController controller, String label, IconData icon) {
    final primaryColor = Theme.of(context).primaryColor;
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (v) => v == null || v.isEmpty ? "Lütfen $label girin" : null,
    );
  }

  void _navigateToGoalPage() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GoalActivityPage(
            initialData: {
              "weight": double.parse(_weightController.text.replaceAll(',', '.')),
              "height_cm": double.parse(_heightController.text.replaceAll(',', '.')),
              "age": int.parse(_ageController.text),
              "sex": _sex,
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}