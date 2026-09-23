"""Model sinflari. Backend'dagi diseases.ai_label shu nomlar bilan bog'lanadi.

PlantVillage papka nomi → AgroYordam ai_label. Model aynan shu (o'ng tomondagi) nomlar bilan o'qitiladi.
"""

PLANTVILLAGE_CLASSES: dict[str, str] = {
    "Tomato___Bacterial_spot": "Tomato_Bacterial_spot",
    "Tomato___Early_blight": "Tomato_Early_blight",
    "Tomato___Late_blight": "Tomato_Late_blight",
    "Tomato___Leaf_Mold": "Tomato_Leaf_Mold",
    "Tomato___Septoria_leaf_spot": "Tomato_Septoria_leaf_spot",
    "Tomato___Spider_mites Two-spotted_spider_mite": "Tomato_Spider_mites",
    "Tomato___Target_Spot": "Tomato_Target_Spot",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": "Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato___Tomato_mosaic_virus": "Tomato_mosaic_virus",
    "Tomato___healthy": "Tomato_healthy",
    "Potato___Early_blight": "Potato_Early_blight",
    "Potato___Late_blight": "Potato_Late_blight",
    "Potato___healthy": "Potato_healthy",
    "Pepper,_bell___Bacterial_spot": "Pepper_Bacterial_spot",
    "Pepper,_bell___healthy": "Pepper_healthy",
    "Grape___Black_rot": "Grape_Black_rot",
    "Grape___Esca_(Black_Measles)": "Grape_Esca",
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": "Grape_Leaf_blight",
    "Grape___healthy": "Grape_healthy",
    "Apple___Apple_scab": "Apple_Scab",
    "Apple___Black_rot": "Apple_Black_rot",
    "Apple___Cedar_apple_rust": "Apple_Cedar_rust",
    "Apple___healthy": "Apple_healthy",
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot": "Corn_Gray_leaf_spot",
    "Corn_(maize)___Common_rust_": "Corn_Common_rust",
    "Corn_(maize)___Northern_Leaf_Blight": "Corn_Northern_Leaf_Blight",
    "Corn_(maize)___healthy": "Corn_healthy",
    "Peach___Bacterial_spot": "Peach_Bacterial_spot",
    "Peach___healthy": "Peach_healthy",
    "Cherry_(including_sour)___Powdery_mildew": "Cherry_Powdery_mildew",
    "Cherry_(including_sour)___healthy": "Cherry_healthy",
    "Strawberry___Leaf_scorch": "Strawberry_Leaf_scorch",
    "Strawberry___healthy": "Strawberry_healthy",
    "Squash___Powdery_mildew": "Squash_Powdery_mildew",
}

# O'zbekcha ekin nomi → ai_label prefiksi
PLANT_PREFIX: dict[str, str] = {
    "Pomidor": "Tomato",
    "Kartoshka": "Potato",
    "Bolgar qalampiri": "Pepper",
    "Uzum": "Grape",
    "Olma": "Apple",
    "Makkajo'xori": "Corn",
    "Shaftoli": "Peach",
    "Olcha": "Cherry",
    "Qulupnay": "Strawberry",
    "Qovoq": "Squash",
    "Bodring": "Cucumber",
}
PREFIX_PLANT = {v: k for k, v in PLANT_PREFIX.items()}

MODEL_LABELS = sorted(set(PLANTVILLAGE_CLASSES.values()))

# Stub rejimi uchun (model yo'q bo'lganda) ekin → sinflar
PLANT_LABELS: dict[str, list[str]] = {}
for _lbl in MODEL_LABELS + ["Cucumber_Powdery_mildew", "Cucumber_Root_rot", "Cucumber_healthy"]:
    PLANT_LABELS.setdefault(PREFIX_PLANT[_lbl.split("_")[0]], []).append(_lbl)

ALL_LABELS = [lbl for labels in PLANT_LABELS.values() for lbl in labels]


def plant_of(label: str) -> str | None:
    return PREFIX_PLANT.get(label.split("_")[0])
