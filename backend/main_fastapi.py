from fastapi import FastAPI
from pydantic import BaseModel, Field
from typing import Literal, Optional
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
import os
from typing import List, Dict, Any  # Yeni tipler

# --- GLOBAL DEĞİŞKENLER VE VERİ YÖNETİMİ ---
recipe_data = pd.DataFrame()
exercise_data = pd.DataFrame()

# Aktivite katsayıları (TDEE hesaplaması için)
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

# --- VERİ YÜKLEME FONKSİYONU ---
# YENİ FONKSİYON: load_and_clean_data (Ölçeklendirme Eklendi)
def load_and_clean_data(file_path: str):
    """Veri setini yükler, temizler, tipleri zorlar ve kalorileri ölçeklendirir."""
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
        # Ortalama kalori 1 kcal civarında olduğu için, bunu gerçekçi bir öğün kalorisine çıkarıyoruz.
        # Maksimum öğün kalorisinin 800 kcal olduğunu varsayıyoruz.
        if 'calories' in recipe_data.columns:
            # Sütundaki maksimum değeri bul
            max_cal_in_data = recipe_data['calories'].max()

            # Eğer max değer 1'den küçükse (normalleştirilmiş demektir) ölçeklendir
            if max_cal_in_data < 10 and max_cal_in_data > 0:
                SCALE_FACTOR = 800 / max_cal_in_data
                recipe_data['calories'] = recipe_data['calories'] * SCALE_FACTOR

                # Diğer makro değerlerini de aynı oranda ölçeklendirmek mantıklıdır
                # (Eğer onlar da normalleştirilmişse ve kcal olarak varsayılıyorsa)
                recipe_data['protein'] = recipe_data['protein'] * SCALE_FACTOR
                recipe_data['fat'] = recipe_data['fat'] * SCALE_FACTOR
                recipe_data['carbs'] = recipe_data['carbs'] * SCALE_FACTOR
                print(f"VERİ DÜZELTME: Kalori ve Makro sütunları x{SCALE_FACTOR:.0f} kat ölçeklendirildi.")

        print("Veri temizleme (NaN doldurma ve tip dönüşümü) tamamlandı.")

    except Exception as e:
        print(f"Veri yükleme veya temizleme sırasında bir hata oluştu: {e}")


# --- YENİ VERİ YÜKLEME FONKSİYONU: Egzersiz Verisi (Düzeltilmiş) ---
def load_exercise_data(file_path: str):
    """Egzersiz veri setini yükler, temel temizliği yapar ve exercise_data global değişkenine atar."""
    global exercise_data

    if not os.path.exists(file_path):
        print(f"HATA: Egzersiz Dosyası bulunamadı - {file_path}")
        return

    try:
        exercise_data = pd.read_csv(file_path)
        print(f"'{file_path}' başarıyla yüklendi. Toplam {len(exercise_data)} egzersiz kaydı.")

        # Kullanıcıdan gelen kesin sütun adlarını kullanıyoruz:
        numeric_cols = ['Calories_Burned', 'Session_Duration (hours)', 'Weight (kg)', 'Age', 'Height (m)']

        for col in numeric_cols:
            if col in exercise_data.columns:
                # Sayısal tipe çevirip (hata durumunda NaN yapar), NaN'ları 0 ile doldurur.
                exercise_data[col] = pd.to_numeric(exercise_data[col], errors='coerce').fillna(0)
            else:
                print(f"UYARI: Egzersiz Verisi: '{col}' sütunu bulunamadı.")

        print("Egzersiz verisi temizliği tamamlandı. Ölçeklendirme yapılmadı.")

    except Exception as e:
        print(f"Egzersiz verisi yükleme veya temizleme sırasında bir hata oluştu: {e}")


# --- LİFESPAN TANIMLAMA (YENİ YÖNTEM) ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Uygulama yaşam döngüsü yöneticisi: Başlangıçta verileri yükler."""

    # KENDİ DOSYA YOLUMUZU BURADA TANIMLIYORUZ (Raw String kullanarak kaçış sorununu çözdük)
    FILE_PATH = r"C:\Users\Betul\Downloads\healthy_meal_plans.csv"
    EXERCISE_FILE_PATH = r"C:\Users\Betul\Downloads\gym_members_exercise_tracking.csv"

    # VERİ YÜKLEME İŞLEMİ (Startup)
    print(">>> Uygulama Başlangıcı: Veri yükleniyor...")
    load_and_clean_data(FILE_PATH)
    load_exercise_data(EXERCISE_FILE_PATH)

    yield  # Uygulamanın çalışmaya başlaması için bekleme noktası

    # Kapanış işlemleri buraya gelebilir
    print(">>> Uygulama Kapanışı...")


# --- FASTAPI TANIMLAMASI VE LIFESPAN ENTEGRASYONU ---
app = FastAPI(title="Kişiselleştirilmiş Beslenme API", lifespan=lifespan)

# --- CORS KONFİGÜRASYONU ---
# Geliştirme aşamasında CORS (Cross-Origin Resource Sharing) kısıtlamalarını kaldırıyoruz.
# Böylece farklı bir domain'den (örneğin frontend tarafında React, Flutter Web, vs.) gelen istekler engellenmez.
# Production (canlı sistem) ortamında güvenlik için bu izinleri daraltmak gerekir.
app.add_middleware(
    CORSMiddleware,  # CORS işlemlerini yönetmek için FastAPI'nin hazır middleware'ini ekledik.
    allow_origins=["*"],  # Tüm kaynaklardan (domain) gelen isteklere izin veriyoruz.
    # (Canlı ortamda sadece belirli domain’lere izin verilmeli.)
    allow_methods=["*"],  # GET, POST, PUT, DELETE gibi tüm HTTP metodlarına izin veriyoruz.
    allow_headers=["*"],  # Tüm başlıklara (headers) izin veriyoruz — örneğin Authorization, Content-Type, vs.
)

# --- INPUT VE HESAPLAMA MODELLERİ ---
class UserInput(BaseModel):
    weight: float = Field(..., gt=0, description="Ağırlık (kg)")
    height_cm: float = Field(..., gt=0, description="Boy (cm)")
    age: int = Field(..., ge=0, description="Yaş")
    sex: Literal["male", "female", "m", "f"] = "male"
    # YENİ ALAN: Aktivite Seviyesi (TDEE için)
    activity_level: Literal["sedentary", "light", "moderate", "active", "very_active"] = "sedentary"
    # Adım 3 için kullanılacak
    goal: Literal["lose", "gain", "maintain"] = "maintain"
    # Adım 4 için varsayılanlar (Flutter'dan geldiği varsayılıyor)
    is_vegetarian: bool = Field(False, description="Kullanıcı vejetaryen mi?")
    is_vegan: bool = Field(False, description="Kullanıcı vegan mı?")


def calc_bmi(weight: float, height_cm: float) -> float:
    h = height_cm / 100.0
    return weight / (h * h)


def calc_bmr_mifflin(weight: float, height_cm: float, age: int, sex: str) -> float:
    base = 10 * weight + 6.25 * height_cm - 5 * age
    # Base + 5 (erkek) veya Base - 161 (kadın)
    return base + 5 if str(sex).lower().startswith("m") else base - 161


# YENİ HESAPLAMA: TDEE
def calc_tdee(bmr: float, activity_level: str) -> float:
    """TDEE = BMR * Aktivite Katsayısı (Adım 2'deki Regresyon Tahmini)"""
    factor = ACTIVITY_FACTORS.get(activity_level.lower(), 1.2)
    return bmr * factor


# YENİ FONKSİYON: Kalori ve Makro Hedef Belirleme (Adım 3)
def determine_targets(tdee: float, goal: str) -> dict:
    """Kullanıcının TDEE'sine ve hedefine göre kalori ve makro hedeflerini belirler."""

    # 1. Kalori Hedefi
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


# YENİ FONKSİYON: Tarif Filtreleme (Kısıtlamalar Eklendi ve Düzeltildi)
def filter_recipes(target_cal: float, is_vegetarian: bool, is_vegan: bool) -> List[Dict[str, Any]]:
    """Hedef kalori aralığına en yakın 5 tarifi, diyet kısıtlamalarına göre filtreler."""
    global recipe_data

    if recipe_data.empty:
        return []

    df_selected = recipe_data.copy()

    # --- 1. Kural Tabanlı Filtreleme (Vegan/Vejetaryen) ---
    # Bu veri setinde bu etiketlerin 'vegan' ve 'vegetarian' sütun adlarıyla 0/1 değerleri olduğunu varsayıyoruz.

    if is_vegan:
        # Vegan kuralı: Sadece vegan etiketi 1 olanları seç
        if 'vegan' in df_selected.columns:
            df_selected = df_selected[df_selected['vegan'] == 1].copy()
            print("DEBUG: Vegan kısıtlaması uygulandı.")

    elif is_vegetarian:
        # Vejetaryen kuralı: Sadece vejetaryen etiketi 1 olanları seç (vegan olmayanları da içerir)
        if 'vegetarian' in df_selected.columns:
            # Hem vejetaryen etiketi 1 olanları hem de vegan etiketi 1 olanları seç
            df_selected = df_selected[df_selected['vegetarian'] == 1].copy()
            print("DEBUG: Vejetaryen kısıtlaması uygulandı.")

    if df_selected.empty:
        # Kısıtlamadan sonra hiç tarif kalmadıysa
        return []

    # --- 2. Kalori Farkını Hesapla ve Sırala ---
    MEALS_PER_DAY = 4
    target_meal_cal = target_cal / MEALS_PER_DAY

    df_selected['cal_diff'] = (df_selected['calories'] - target_meal_cal).abs()
    df_selected['random_sort'] = np.random.rand(len(df_selected))

    final_recipes = df_selected.sort_values(
        by=['cal_diff', 'calories', 'random_sort'],
        ascending=[True, True, True]
    ).head(5).reset_index(drop=True)

    return final_recipes.drop(columns=['cal_diff', 'random_sort']).to_dict('records')


# YENİ FONKSİYON: Egzersizleri Filtreleme (Verimliliğe Dayalı)
def filter_exercises(goal: str) -> List[Dict[str, Any]]:
    """Kullanıcının hedefine uygun türlerdeki en verimli 4 egzersizi filtreler ve döndürür."""
    global exercise_data

    # 1. Ön Kontrol
    if exercise_data.empty or 'Workout_Type' not in exercise_data.columns or 'Session_Duration (hours)' not in exercise_data.columns:
        return []

    df_ex = exercise_data.copy()

    # Session_Duration 0 olamaz (bölme hatası verir), 0 olanları ortadan kaldırıyoruz
    df_ex = df_ex[df_ex['Session_Duration (hours)'] > 0].copy()

    # 2. Kalori Verimliliği Hesaplama (KRİTİK: Saatte Yakılan Kalori)
    df_ex['Calorie_Efficiency'] = df_ex['Calories_Burned'] / df_ex['Session_Duration (hours)']

    # 3. Hedefe Göre Filtreleme Kuralı
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

    most_efficient_session = filtered_df.sort_values(by='Calorie_Efficiency',ascending=False).head(1).iloc[0]  # Head(1) ile en üstteki satırı alıyoruz.
    # 4. Çıktı Listesini Oluşturma (1 Antrenman + 3 Hareket)
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


# YENİ FONKSİYON: Tarif Filtreleme (Kısıtlamalar Eklendi ve Düzeltildi)
def filter_recipes(target_cal: float, is_vegetarian: bool, is_vegan: bool) -> List[Dict[str, Any]]:
    """Hedef kalori aralığına en yakın 5 tarifi, diyet kısıtlamalarına göre filtreler."""
    global recipe_data

    if recipe_data.empty:
        return []

    df_selected = recipe_data.copy()

    # --- 1. Kural Tabanlı Filtreleme (Vegan/Vejetaryen) ---
    # Bu veri setinde bu etiketlerin 'vegan' ve 'vegetarian' sütun adlarıyla 0/1 değerleri olduğunu varsayıyoruz.

    if is_vegan:
        # Vegan kuralı: Sadece vegan etiketi 1 olanları seç
        if 'vegan' in df_selected.columns:
            df_selected = df_selected[df_selected['vegan'] == 1].copy()
            print("DEBUG: Vegan kısıtlaması uygulandı.")

    elif is_vegetarian:
        # Vejetaryen kuralı: Sadece vejetaryen etiketi 1 olanları seç (vegan olmayanları da içerir)
        if 'vegetarian' in df_selected.columns:
            # Hem vejetaryen etiketi 1 olanları hem de vegan etiketi 1 olanları seç
            df_selected = df_selected[df_selected['vegetarian'] == 1].copy()
            print("DEBUG: Vejetaryen kısıtlaması uygulandı.")

    if df_selected.empty:
        # Kısıtlamadan sonra hiç tarif kalmadıysa
        return []

    # --- 2. Kalori Farkını Hesapla ve Sırala ---
    MEALS_PER_DAY = 4
    target_meal_cal = target_cal / MEALS_PER_DAY

    df_selected['cal_diff'] = (df_selected['calories'] - target_meal_cal).abs()
    df_selected['random_sort'] = np.random.rand(len(df_selected))

    final_recipes = df_selected.sort_values(
        by=['cal_diff', 'calories', 'random_sort'],
        ascending=[True, True, True]
    ).head(5).reset_index(drop=True)

    return final_recipes.drop(columns=['cal_diff', 'random_sort']).to_dict('records')

# --- ENDPOINT'LER ---
@app.get("/")
def root():
    # Test için veri setinin kaç satır yüklendiğini gösterir
    return {"message": "Backend çalışıyor.",
            "loaded_recipes": len(recipe_data),
            "loaded_exercises": len(exercise_data)}


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


@app.post("/calculate")
def calculate(inp: UserInput):
    """
    Kullanıcı girdilerine göre BMI, BMR, TDEE'yi hesaplar, makro hedeflerini belirler
    ve buna uygun tarifleri filtreler.
    """
    bmi = round(calc_bmi(inp.weight, inp.height_cm), 2)
    bmr = round(calc_bmr_mifflin(inp.weight, inp.height_cm, inp.age, inp.sex), 2)
    tdee = round(calc_tdee(bmr, inp.activity_level), 2)  # TDEE hesaplandı

    # YENİ ADIM: Makro Hedeflerini belirle
    targets = determine_targets(tdee, inp.goal)

    # Şimdilik Adım 4 kısıtlamaları (diyabet, vejetaryen) filtreleme fonksiyonuna dahil edilmedi.
    recommended_recipes = filter_recipes(targets["target_calories"],
                                         inp.is_vegetarian,
                                         inp.is_vegan)

    recommended_exercises = filter_exercises(inp.goal)
    weekly_plan = generate_weekly_plan(recommended_recipes, recommended_exercises, inp.goal)

    # BMI Kategori Mantığı (Önceki Kodunuzdan)
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

    # Adım 3 Çıktısı: Tüm hesaplamaları, hedefleri ve tarif listesini döndürün
    return {
        "bmi": bmi,
        "bmi_category": category,
        "bmr": bmr,
        "tdee": tdee,
        "target_calories": targets["target_calories"],
        "target_macros": targets["target_macros"],
        "recommended_recipes": recommended_recipes,
        "recommended_exercises": recommended_exercises,
        "weekly_plan": weekly_plan,  # YENİ HAFTALIK PLAN
    }