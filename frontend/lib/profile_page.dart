import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'data_models.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  CalculationResult? lastPlan;
  bool _isLoading = true;

  // Bildirim Ayarları Durumları
  bool _waterReminder = true;
  bool _workoutReminder = true;
  bool _mealReminder = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Kullanıcının en son sağlık planını ve BMI verilerini çeker
  Future<void> _fetchUserData() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc('fitplan-pro-v1')
          .collection('users')
          .doc(user!.uid)
          .collection('user_plans')
          .doc('latest_plan')
          .get();

      if (doc.exists) {
        setState(() {
          lastPlan = CalculationResult.fromJson(doc.data()!);
        });
      }
    } catch (e) {
      debugPrint("Veri çekme hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Bildirim Ayarları Paneli ---
  void _showNotificationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Bildirim Ayarları"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text("Su Hatırlatıcısı"),
                subtitle: const Text("Günlük su tüketimi hatırlatması"),
                value: _waterReminder,
                onChanged: (val) {
                  setDialogState(() => _waterReminder = val);
                  setState(() => _waterReminder = val);
                },
              ),
              SwitchListTile(
                title: const Text("Antrenman Hatırlatıcısı"),
                subtitle: const Text("Günlük egzersiz vakti bildirimi"),
                value: _workoutReminder,
                onChanged: (val) {
                  setDialogState(() => _workoutReminder = val);
                  setState(() => _workoutReminder = val);
                },
              ),
              SwitchListTile(
                title: const Text("Öğün Hatırlatıcısı"),
                subtitle: const Text("Sağlıklı öğün zamanı bildirimi"),
                value: _mealReminder,
                onChanged: (val) {
                  setDialogState(() => _mealReminder = val);
                  setState(() => _mealReminder = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("KAYDET"),
            ),
          ],
        ),
      ),
    );
  }

  // --- Hesap Bilgilerini Güncelleme Ekranı ---
  void _showUpdateAccountSheet() {
    if (user == null) return;

    List<String> nameParts = (user!.displayName ?? "").split(" ");
    String currentName = nameParts.isNotEmpty ? nameParts.first : "";
    String currentSurname = nameParts.length > 1 ? nameParts.sublist(1).join(" ") : "";

    final nameController = TextEditingController(text: currentName);
    final surnameController = TextEditingController(text: currentSurname);
    final emailController = TextEditingController(text: user!.email);
    final passwordController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Profil Bilgilerini Güncelle",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "İsim", prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: surnameController,
                decoration: const InputDecoration(labelText: "Soyisim", prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "E-posta", prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Yeni Şifre (Değiştirmek istemiyorsanız boş bırakın)",
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await user!.updateDisplayName("${nameController.text} ${surnameController.text}");
                    if (emailController.text != user!.email) {
                      await user!.verifyBeforeUpdateEmail(emailController.text);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Yeni e-posta adresinize bir doğrulama bağlantısı gönderildi.")),
                        );
                      }
                    }

                    if (passwordController.text.isNotEmpty) {
                      await user!.updatePassword(passwordController.text);
                    }

                    await FirebaseFirestore.instance
                        .collection('artifacts')
                        .doc('fitplan-pro-v1')
                        .collection('users')
                        .doc(user!.uid)
                        .set({
                      'name': nameController.text.trim(),
                      'surname': surnameController.text.trim(),
                      'email': emailController.text.trim(),
                    }, SetOptions(merge: true));

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Profil başarıyla güncellendi.")),
                      );
                      setState(() {}); // UI yenile
                    }
                  } on FirebaseAuthException catch (e) {
                    String errorMsg = "Hata oluştu.";
                    if (e.code == 'requires-recent-login') {
                      errorMsg = "Güvenlik nedeniyle tekrar giriş yapmanız gerekiyor.";
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
                      );
                    }
                  } catch (e) {
                    debugPrint(e.toString());
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text("GÜNCELLE"),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 50, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user?.displayName ?? "Kullanıcı",
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user?.email ?? "",
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Sağlık Özeti"),
                  if (lastPlan != null) ...[
                    _buildStatTile("BMI", lastPlan!.bmi.toStringAsFixed(1), Icons.speed, Colors.orange),
                    _buildStatTile("Durum", lastPlan!.bmiCategory, Icons.info_outline, Colors.blue),
                    _buildStatTile("Hedef Kalori", "${lastPlan!.targetCalories.toInt()} kcal", Icons.local_fire_department, Colors.red),
                  ] else
                    const Card(
                      child: ListTile(
                        title: Text("Henüz bir plan oluşturulmamış."),
                      ),
                    ),

                  const SizedBox(height: 20),
                  _buildSectionTitle("Ayarlar"),
                  _buildSettingsTile("Bilgilerimi Güncelle", Icons.manage_accounts, _showUpdateAccountSheet),
                  _buildSettingsTile("Bildirimler", Icons.notifications, _showNotificationSettingsDialog),

                  const SizedBox(height: 30),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text("Çıkış Yap", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSettingsTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}