import uuid

from sqlalchemy import select

from app.models import Disease, DiseaseMedicine, Medicine, Plant
from app.repositories.base import Repository


class PlantRepository(Repository[Plant]):
    model = Plant


class MedicineRepository(Repository[Medicine]):
    model = Medicine


class DiseaseRepository(Repository[Disease]):
    model = Disease

    async def by_ai_label(self, label: str) -> Disease | None:
        return await self.db.scalar(select(Disease).where(Disease.ai_label == label))

    async def medicines_for(self, disease_id: uuid.UUID) -> list[tuple[Medicine, str | None]]:
        stmt = (
            select(Medicine, DiseaseMedicine.recommendation)
            .join(DiseaseMedicine, DiseaseMedicine.medicine_id == Medicine.id)
            .where(DiseaseMedicine.disease_id == disease_id)
        )
        rows = [(m, r) for m, r in (await self.db.execute(stmt)).all()]
        # Aniq dozasi/jadvali bor (asosiy davolovchi) dori birinchi, "profilaktika uchun" kabilar keyin
        return sorted(rows, key=lambda mr: (not any(ch.isdigit() for ch in (mr[1] or "")), mr[0].name))
