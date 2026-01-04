# Backend kodunuza eklenecek fonksiyon ve güncellemeler
# Bu kodu mevcut backend dosyanıza ekleyin

def get_movement_suggestions(goal: str) -> Dict[str, List[str]]:
    """
    Kullanıcının hedefine göre hareket önerilerini döndürür.
    
    Args:
        goal: "gain", "lose", veya "maintain"
    
    Returns:
        Kategorilere göre ayrılmış hareket listesi
    """
    if goal == "gain":
        # Kas Kazanımı → Strength
        return {
            "Üst Vücut": [
                "Bench Press",
                "Incline Dumbbell Press",
                "Pull-up / Lat Pulldown",
                "Bent-over Barbell Row",
                "Overhead Shoulder Press",
                "Biceps Barbell Curl",
                "Triceps Rope Pushdown"
            ],
            "Alt Vücut": [
                "Back Squat",
                "Deadlift",
                "Romanian Deadlift",
                "Leg Press",
                "Lunges (Forward/Walking)",
                "Hip Thrust",
                "Calf Raise"
            ],
            "Core (Göbek)": [
                "Plank Hold",
                "Hanging Leg Raise",
                "Cable Woodchopper"
            ]
        }
    
    elif goal == "lose":
        # Kilo Verme → Cardio + HIIT + Strength
        return {
            "Cardio Hareketleri": [
                "Koşu bandı (interval veya steady-state)",
                "Eliptik",
                "İp atlama",
                "Tempolu yürüyüş",
                "Bisiklet – spinning",
                "Merdiven çıkma"
            ],
            "HIIT Rutinleri": [
                "Burpee (20-30 saniye yüksek tempo + 10 saniye dinlenme)",
                "Mountain Climber (20-30 saniye yüksek tempo + 10 saniye dinlenme)",
                "High Knees (20-30 saniye yüksek tempo + 10 saniye dinlenme)",
                "Jump Squat (20-30 saniye yüksek tempo + 10 saniye dinlenme)",
                "Kettlebell Swing (20-30 saniye yüksek tempo + 10 saniye dinlenme)",
                "Sprint interval (koşu)"
            ],
            "Strength (Yağ Yakımını Desteklemek için)": [
                "Goblet Squat",
                "Romanian Deadlift",
                "Push-up",
                "Row (kablo veya barbell)",
                "Dumbbell Shoulder Press"
            ]
        }
    
    else:  # maintain
        # Kilo Koruma → Cardio + Yoga + Strength
        return {
            "Cardio": [
                "Tempolu yürüyüş",
                "Hafif koşu",
                "Hafif bisiklet (15-20 dk)",
                "Kürek makinesi (Rowing)"
            ],
            "Yoga": [
                "Sun Salutation (Surya Namaskar)",
                "Warrior Poses (I – II)",
                "Downward Dog",
                "Child's Pose",
                "Cat–Cow mobility movements",
                "Triangle Pose (Trikonasana)"
            ],
            "Strength": [
                "Dumbbell Bench Press",
                "Bulgarian Split Squat",
                "Lat Pulldown",
                "Dumbbell Row",
                "Leg Extension + Leg Curl kombinasyonu",
                "Core: Plank + Russian Twist"
            ]
        }


def get_random_movements(goal: str) -> Dict[str, Any]:
    """
    Hedefe göre hareket önerilerini döndürür.
    
    Args:
        goal: "gain", "lose", veya "maintain"
    
    Returns:
        "gain" için: Kategorilere göre ayrılmış dict (her kategoriden 3 hareket)
        Diğerleri için: 4 rastgele hareket listesi
    """
    import random
    
    all_movements = get_movement_suggestions(goal)
    
    if goal == "gain":
        # Kas kazanımı için: Her kategoriden 3 hareket seç
        result = {}
        for category, exercises in all_movements.items():
            if len(exercises) <= 3:
                result[category] = exercises
            else:
                result[category] = random.sample(exercises, 3)
        return result
    else:
        # "lose" ve "maintain" için: Tüm kategorilerden 4 rastgele hareket
        all_exercises = []
        for category, exercises in all_movements.items():
            all_exercises.extend(exercises)
        
        if len(all_exercises) <= 4:
            return all_exercises
        else:
            return random.sample(all_exercises, 4)


# generate_weekly_plan fonksiyonunu güncelleyin:
def generate_weekly_plan(recommended_recipes: List[Dict[str, Any]], recommended_exercises: List[Dict[str, Any]],
                         goal: str) -> Dict[str, Any]:

    if not recommended_recipes:
        return {"plan": "Kısıtlamalara uygun tarif bulunamadığından plan oluşturulamadı."}

    # Kullanılabilir tarif listesi (5 adet)
    recipes = [r['meal_name'] for r in recommended_recipes]

    main_workout = recommended_exercises[0] if recommended_exercises else None
    workout_days = ['Pazartesi', 'Çarşamba', 'Cuma']
    weekly_plan = {}

    # Planı oluşturma döngüsü
    for i in range(7):
        day_index = i % 7
        day_name = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'][day_index]

        # Her gün için 3 öğün (Kahvaltı, Öğle, Akşam)
        daily_meals = {
            "Kahvaltı": recipes[i % len(recipes)],
            "Öğle": recipes[(i + 1) % len(recipes)],
            "Akşam": recipes[(i + 2) % len(recipes)],
        }

        daily_plan = {
            "Öğünler": daily_meals,
            "Egzersiz": "Dinlenme/Hafif Kardiyo"
            # Hareketler sadece egzersiz günlerinde eklenecek
        }

        # Egzersiz planını ekle
        if main_workout and day_name in workout_days:
            # Antrenman günleri için ana seansı ata
            daily_plan["Egzersiz"] = (
                f"{main_workout['Workout_Type']} ({main_workout['Session_Duration (hours)']:.1f} saat) - Hedef: {goal}."
            )
            # Egzersiz günlerinde hareket önerilerini al
            # "gain" için kategorilere göre dict, diğerleri için liste döner
            movements = get_random_movements(goal)
            daily_plan["Hareketler"] = movements
        # Dinlenme günlerinde hareketler eklenmez (boş kalır)

        weekly_plan[day_name] = daily_plan

    return {"Haftalık Plan": weekly_plan}

