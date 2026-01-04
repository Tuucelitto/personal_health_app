from fastapi import FastAPI
from pydantic import BaseModel, Field
from typing import Literal, Optional
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import pandas as pd
import numpy as np
import os
from typing import List, Dict, Any  # Yeni tipler

recipe_data = pd.DataFrame()
exercise_data = pd.DataFrame()

ACTIVITY_FACTORS = {
    "sedentary": 1.2,  # Hareketsiz (çok az egzersiz)
    "light": 1.375,  # Hafif aktif (haftada 1-3 gün hafif egzersiz)
    "moderate": 1.55,  # Orta aktif (haftada 3-5 gün orta egzersiz)
    "active": 1.725,  # Çok aktif (haftada 6-7 gün yoğun egzersiz)
    "very_active": 1.9  # Aşırı aktif (günde çift antrenman veya fiziksel iş)
}

SAMPLE_MOVEMENTS = {
    "Strength": ["Squat", "Bench Press", "Overhead Press"],
    "Cardio": ["High Knees", "Jumping Jacks", "Burpees"],
    "HIIT": ["Sprints", "Box Jumps", "Kettlebell Swings"],
    "Yoga": ["Downward Dog", "Warrior II", "Tree Pose"],
}

def load_and_clean_data(file_path: str):
    global recipe_data

    try:
        recipe_data = pd.read_csv(file_path)
        print(f"'{file_path}' başarıyla yüklendi. Toplam {len(recipe_data)} tarif.")

        macro_cols = ['calories', 'protein', 'fat', 'carbs']

        for col in macro_cols:
            if col in recipe_data.columns:
                recipe_data[col] = pd.to_numeric(recipe_data[col], errors='coerce')
                recipe_data[col] = recipe_data[col].fillna(0)
            else:
                print(f"UYARI: '{col}' sütunu veri setinde bulunamadı. Lütfen kontrol edin.")

        # --- KALORİ ÖLÇEKLENDİRMESİ ---
        if 'calories' in recipe_data.columns:
            max_cal_in_data = recipe_data['calories'].max()

            if max_cal_in_data < 10 and max_cal_in_data > 0:
                SCALE_FACTOR = 800 / max_cal_in_data
                recipe_data['calories'] = recipe_data['calories'] * SCALE_FACTOR
                recipe_data['protein'] = recipe_data['protein'] * SCALE_FACTOR
                recipe_data['fat'] = recipe_data['fat'] * SCALE_FACTOR
                recipe_data['carbs'] = recipe_data['carbs'] * SCALE_FACTOR
                print(f"VERİ DÜZELTME: Kalori ve Makro sütunları x{SCALE_FACTOR:.0f} kat ölçeklendirildi.")

        print("Veri temizleme (NaN doldurma ve tip dönüşümü) tamamlandı.")

    except Exception as e:
        print(f"Veri yükleme veya temizleme sırasında bir hata oluştu: {e}")


def load_exercise_data(file_path: str):
    global exercise_data

    if not os.path.exists(file_path):
        print(f"HATA: Egzersiz Dosyası bulunamadı - {file_path}")
        return

    try:
        exercise_data = pd.read_csv(file_path)
        print(f"'{file_path}' başarıyla yüklendi. Toplam {len(exercise_data)} egzersiz kaydı.")

        numeric_cols = ['Calories_Burned', 'Session_Duration (hours)', 'Weight (kg)', 'Age', 'Height (m)']

        for col in numeric_cols:
            if col in exercise_data.columns:
                exercise_data[col] = pd.to_numeric(exercise_data[col], errors='coerce').fillna(0)
            else:
                print(f"UYARI: Egzersiz Verisi: '{col}' sütunu bulunamadı.")

        print("Egzersiz verisi temizliği tamamlandı. Ölçeklendirme yapılmadı.")

    except Exception as e:
        print(f"Egzersiz verisi yükleme veya temizleme sırasında bir hata oluştu: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):

    FILE_PATH = r"C:\Users\Betul\Downloads\healthy_meal_plans.csv"
    EXERCISE_FILE_PATH = r"C:\Users\Betul\Downloads\gym_members_exercise_tracking.csv"
    print(">>> Uygulama Başlangıcı: Veri yükleniyor...")
    load_and_clean_data(FILE_PATH)
    load_exercise_data(EXERCISE_FILE_PATH)

    yield
    print(">>> Uygulama Kapanışı...")


app = FastAPI(title="Kişiselleştirilmiş Beslenme API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class UserInput(BaseModel):
    weight: float = Field(..., gt=0, description="Ağırlık (kg)")
    height_cm: float = Field(..., gt=0, description="Boy (cm)")
    age: int = Field(..., ge=0, description="Yaş")
    sex: Literal["male", "female", "m", "f"] = "male"
    activity_level: Literal["sedentary", "light", "moderate", "active", "very_active"] = "sedentary"
    goal: Literal["lose", "gain", "maintain"] = "maintain"
    is_vegetarian: bool = Field(False, description="Kullanıcı vejetaryen mi?")
    is_vegan: bool = Field(False, description="Kullanıcı vegan mı?")


def calc_bmi(weight: float, height_cm: float) -> float:
    h = height_cm / 100.0
    return weight / (h * h)


def calc_bmr_mifflin(weight: float, height_cm: float, age: int, sex: str) -> float:
    base = 10 * weight + 6.25 * height_cm - 5 * age
    # Base + 5 (erkek) veya Base - 161 (kadın)
    return base + 5 if str(sex).lower().startswith("m") else base - 161


def calc_tdee(bmr: float, activity_level: str) -> float:
    factor = ACTIVITY_FACTORS.get(activity_level.lower(), 1.2)
    return bmr * factor


def determine_targets(tdee: float, goal: str) -> dict:

    target_cal = tdee
    if goal == "lose":
        target_cal = max(tdee - 500, 1200)
        macros = {"P_perc": 0.35, "C_perc": 0.35, "F_perc": 0.30}
    elif goal == "gain":
        target_cal = tdee + 500
        macros = {"P_perc": 0.30, "C_perc": 0.45, "F_perc": 0.25}
    else:  # maintain
        target_cal = tdee
        macros = {"P_perc": 0.25, "C_perc": 0.50, "F_perc": 0.25}

    return {
        "target_calories": round(target_cal, 2),
        "target_macros": {
            "protein_perc": macros["P_perc"],
            "carbs_perc": macros["C_perc"],
            "fat_perc": macros["F_perc"]
        }
    }


def filter_recipes(target_cal: float, is_vegetarian: bool, is_vegan: bool) -> List[Dict[str, Any]]:
    global recipe_data

    if recipe_data.empty:
        return []

    df_selected = recipe_data.copy()

    if is_vegan:
        if 'vegan' in df_selected.columns:
            df_selected = df_selected[df_selected['vegan'] == 1].copy()
            print("DEBUG: Vegan kısıtlaması uygulandı.")

    elif is_vegetarian:
        if 'vegetarian' in df_selected.columns:
            df_selected = df_selected[df_selected['vegetarian'] == 1].copy()
            print("DEBUG: Vejetaryen kısıtlaması uygulandı.")

    if df_selected.empty:
        return []

    MEALS_PER_DAY = 4
    target_meal_cal = target_cal / MEALS_PER_DAY

    df_selected['cal_diff'] = (df_selected['calories'] - target_meal_cal).abs()
    df_selected['random_sort'] = np.random.rand(len(df_selected))

    final_recipes = df_selected.sort_values(
        by=['cal_diff', 'calories', 'random_sort'],
        ascending=[True, True, True]
    ).head(5).reset_index(drop=True)

    return final_recipes.drop(columns=['cal_diff', 'random_sort']).to_dict('records')


def filter_exercises(goal: str) -> List[Dict[str, Any]]:
    global exercise_data

    if exercise_data.empty or 'Workout_Type' not in exercise_data.columns or 'Session_Duration (hours)' not in exercise_data.columns:
        return []

    df_ex = exercise_data.copy()

    df_ex = df_ex[df_ex['Session_Duration (hours)'] > 0].copy()

    df_ex['Calorie_Efficiency'] = df_ex['Calories_Burned'] / df_ex['Session_Duration (hours)']

    if goal == "gain":
        # Kas Kazanımı: Kuvvet (Strength) egzersizlerine odaklan
        target_types = ['Strength']
    elif goal == "lose":
        # Kilo Verme: Kardiyo (Cardio) ve HIIT egzersizlerine odaklan (En Yüksek Kalori Verimliliği)
        target_types = ['Cardio', 'HIIT', 'Strength']
    else:  # maintain
        # Kilo Koruma: Dengeli
        target_types = ['Cardio', 'Yoga', 'Strength']

    filtered_df = df_ex[df_ex['Workout_Type'].isin(target_types)].copy()

    if filtered_df.empty:
        print("DEBUG: Hedef tipe uygun egzersiz bulunamadı, genel havuzdan seçiliyor.")
        filtered_df = df_ex.copy()

    most_efficient_session = filtered_df.sort_values(by='Calorie_Efficiency',ascending=False).head(1).iloc[0]
    output_list = []

    main_type = most_efficient_session['Workout_Type']
    output_list.append({
        "Workout_Type": f"ANA ONERI: {main_type}",
        "Session_Duration (hours)": most_efficient_session['Session_Duration (hours)'],
        "Calories_Burned": most_efficient_session['Calories_Burned'],
        "Calorie_Efficiency": most_efficient_session['Calorie_Efficiency'],
        "description": "Bu seans, günlük hedefiniz için önerilen temel antrenmandır."
    })

    return output_list

# --- ENDPOINT'LER ---
@app.get("/")
def root():
    # Test için veri setinin kaç satır yüklendiğini gösterir
    return {"message": "Backend çalışıyor.",
            "loaded_recipes": len(recipe_data),
            "loaded_exercises": len(exercise_data)}


def get_movement_suggestions(goal: str) -> Dict[str, List[str]]:

    if goal == "gain":
        # Kas Kazanımı → Strength
        return {
            "Ust Vucut": [
                "Bench Press",
                "Incline Dumbbell Press",
                "Pull-up / Lat Pulldown",
                "Bent-over Barbell Row",
                "Overhead Shoulder Press",
                "Biceps Barbell Curl",
                "Triceps Rope Pushdown"
            ],
            "Alt Vucut": [
                "Back Squat",
                "Deadlift",
                "Romanian Deadlift",
                "Leg Press",
                "Lunges (Forward/Walking)",
                "Hip Thrust",
                "Calf Raise"
            ],
            "Core (Gobek)": [
                "Plank Hold",
                "Hanging Leg Raise",
                "Cable Woodchopper"
            ]
        }

    elif goal == "lose":
        # Kilo Verme → Cardio + HIIT + Strength
        return {
            "Cardio Hareketleri": [
                "Kosu bandi (interval veya steady-state)",
                "Eliptik",
                "İp atlama",
                "Tempolu yuruyus",
                "Bisiklet veya spinning",
                "Merdiven cikma"
            ],
            "HIIT Rutinleri": [
                "Burpee (20-30 saniye yuksek tempo + 10 saniye dinlenme)",
                "Mountain Climber (20-30 saniye yuksek tempo + 10 saniye dinlenme)",
                "High Knees (20-30 saniye yuksek tempo + 10 saniye dinlenme)",
                "Jump Squat (20-30 saniye yuksek tempo + 10 saniye dinlenme)",
                "Kettlebell Swing (20-30 saniye yuksek tempo + 10 saniye dinlenme)",
                "Sprint interval (kosu)"
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
                "Tempolu yuruyus",
                "Hafif kosu",
                "Hafif bisiklet (15-20 dk)",
                "Kurek makinesi (Rowing)"
            ],
            "Yoga": [
                "Sun Salutation (Surya Namaskar)",
                "Warrior Poses (I II)",
                "Downward Dog",
                "Child's Pose",
                "Cat Cow mobility movements",
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
    import random
    all_movements = get_movement_suggestions(goal)

    if goal == "gain":
        result = {}
        for category, exercises in all_movements.items():
            if len(exercises) <= 3:
                result[category] = exercises
            else:
                result[category] = random.sample(exercises, 3)
        return result
    else:
        all_exercises = []
        for category, exercises in all_movements.items():
            all_exercises.extend(exercises)

        if len(all_exercises) <= 4:
            return all_exercises
        else:
            return random.sample(all_exercises, 4)

def generate_weekly_plan(recommended_recipes: List[Dict[str, Any]], recommended_exercises: List[Dict[str, Any]],
                         goal: str) -> Dict[str, Any]:
    if not recommended_recipes:
        return {"plan": "Kısıtlamalara uygun tarif bulunamadığından plan oluşturulamadı."}

    recipes = [r['meal_name'] for r in recommended_recipes]

    main_workout = recommended_exercises[0] if recommended_exercises else None
    workout_days = ['Pazartesi', 'Çarşamba', 'Cuma']
    weekly_plan = {}

    # Planı oluşturma döngüsü
    for i in range(7):
        day_index = i % 7
        day_name = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'][day_index]

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

        if main_workout and day_name in workout_days:
            daily_plan["Egzersiz"] = (
                f"{main_workout['Workout_Type']} ({main_workout['Session_Duration (hours)']:.1f} saat) - Hedef: {goal}."
            )
            movements = get_random_movements(goal)
            daily_plan["Hareketler"] = movements

        weekly_plan[day_name] = daily_plan

    return {"Haftalık Plan": weekly_plan}


@app.post("/calculate")
def calculate(inp: UserInput):
    bmi = round(calc_bmi(inp.weight, inp.height_cm), 2)
    bmr = round(calc_bmr_mifflin(inp.weight, inp.height_cm, inp.age, inp.sex), 2)
    tdee = round(calc_tdee(bmr, inp.activity_level), 2)

    targets = determine_targets(tdee, inp.goal)
    recommended_recipes = filter_recipes(targets["target_calories"],
                                         inp.is_vegetarian,
                                         inp.is_vegan)

    recommended_exercises = filter_exercises(inp.goal)
    weekly_plan = generate_weekly_plan(recommended_recipes, recommended_exercises, inp.goal)

    if bmi < 18.5:
        category = "ZAYIF"
    elif bmi < 25:
        category = "NORMAL"
    elif bmi < 30:
        category = "FAZLA KILOLU"
    elif bmi < 40:
        category = "OBEZ"
    else:
        category = "ASIRI OBEZ"

    return {
        "bmi": bmi,
        "bmi_category": category,
        "bmr": bmr,
        "tdee": tdee,
        "target_calories": targets["target_calories"],
        "target_macros": targets["target_macros"],
        "recommended_recipes": recommended_recipes,
        "recommended_exercises": recommended_exercises,
        "weekly_plan": weekly_plan,
    }