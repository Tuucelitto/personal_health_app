import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'data_models.dart';
import 'main.dart';

class GoalActivityPage extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const GoalActivityPage({super.key, required this.initialData});

  @override
  State<GoalActivityPage> createState() => _GoalActivityPageState();
}

class _GoalActivityPageState extends State<GoalActivityPage> {
  String _activityLevel = "moderate";
  String _goal = "maintain";
  bool _isVegetarian = false;
  bool _isVegan = false;
  bool _isLoading = false;
  final String apiUrl = "http://10.0.2.2:8000/calculate";

  Future<void> _savePlanToFirestore(CalculationResult result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    const String appId = "fitplan-pro-v1";

    try {
      await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('users')
          .doc(user.uid)
          .collection('user_plans')
          .doc('latest_plan')
          .set(result.toMap());

      debugPrint("BAŞARI: Plan buluta yedeklendi.");
    } catch (e) {
      debugPrint("HATA: Firestore kaydı başarısız: $e");
    }
  }

  Future<void> _sendDataAndNavigate() async {
    setState(() => _isLoading = true);

    final body = jsonEncode({
      ...widget.initialData,
      "activity_level": _activityLevel,
      "goal": _goal,
      "has_diabetes": false,
      "is_vegetarian": _isVegetarian,
      "is_vegan": _isVegan,
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = CalculationResult.fromJson(data);
        await _savePlanToFirestore(result);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SummaryPage(result: result)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: ${response.statusCode}\n${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bağlantı hatası: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("2. Adım: Hedef & Kısıtlamalar"),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          children: [
            _buildSectionTitle("Uygulamayı Kullanım Amacınız"),
            _buildInputCard(children: [_buildGoalSelection(primaryColor)]),

            _buildSectionTitle("Fiziksel Aktivite Seviyeniz"),
            _buildInputCard(children: [
              _buildActivitySelection(primaryColor)
            ]),

            _buildSectionTitle("Özel Diyet Kısıtlamaları"),
            _buildInputCard(children: [
              _buildDietSwitch(
                  title: "Vejetaryenim",
                  value: _isVegetarian,
                  onChanged: (val) {
                    setState(() {
                      _isVegetarian = val;
                      if (!val) _isVegan = false;
                    });
                  },
                  primaryColor: primaryColor
              ),
              const Divider(height: 0),
              _buildDietSwitch(
                  title: "Veganım",
                  value: _isVegan,
                  onChanged: (val) {
                    setState(() {
                      _isVegan = val;
                      if (val) _isVegetarian = true;
                    });
                  },
                  primaryColor: primaryColor
              ),
            ]),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _sendDataAndNavigate,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 8,
              ),
              child: const Text("PLAN OLUŞTUR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({required List<Widget> children}) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildGoalSelection(Color primaryColor) {
    return DropdownButtonFormField<String>(
      value: _goal,
      items: const [
        DropdownMenuItem(value: "lose", child: Text("Kilo Verme")),
        DropdownMenuItem(value: "gain", child: Text("Kilo Alma / Kas Kazanımı")),
        DropdownMenuItem(value: "maintain", child: Text("Kilo Koruma")),
      ],
      onChanged: (val) => setState(() => _goal = val!),
      decoration: InputDecoration(
        labelText: "Amacım",
        prefixIcon: Icon(Icons.star, color: primaryColor.withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildActivitySelection(Color primaryColor) {
    return DropdownButtonFormField<String>(
      value: _activityLevel,
      items: const [
        DropdownMenuItem(value: "sedentary", child: Text("Hareketsiz")),
        DropdownMenuItem(value: "light", child: Text("Hafif Aktif")),
        DropdownMenuItem(value: "moderate", child: Text("Orta Aktif")),
        DropdownMenuItem(value: "active", child: Text("Aktif")),
        DropdownMenuItem(value: "very_active", child: Text("Çok Aktif")),
      ],
      onChanged: (val) => setState(() => _activityLevel = val!),
      decoration: InputDecoration(
        labelText: "Aktivite Seviyesi",
        prefixIcon: Icon(Icons.directions_run, color: primaryColor.withOpacity(0.7)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDietSwitch({required String title, required bool value, required ValueChanged<bool> onChanged, required Color primaryColor}) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: primaryColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}