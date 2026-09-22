"""Model sinflari. Backend'dagi diseases.ai_label shu nomlar bilan bog'lanadi."""

PLANT_LABELS: dict[str, list[str]] = {
    "Pomidor": ["Tomato_Late_blight", "Tomato_Early_blight", "Tomato_Bacterial_spot", "Tomato_healthy"],
    "Kartoshka": ["Potato_Late_blight", "Potato_Early_blight", "Potato_healthy"],
    "Bolgar qalampiri": ["Pepper_Bacterial_spot", "Pepper_healthy"],
    "Bodring": ["Cucumber_Powdery_mildew", "Cucumber_Root_rot", "Cucumber_healthy"],
    "Uzum": ["Grape_Black_rot", "Grape_Powdery_mildew", "Grape_healthy"],
    "Olma": ["Apple_Scab", "Apple_healthy"],
}

ALL_LABELS = [lbl for labels in PLANT_LABELS.values() for lbl in labels]


def plant_of(label: str) -> str | None:
    for plant, labels in PLANT_LABELS.items():
        if label in labels:
            return plant
    return None
