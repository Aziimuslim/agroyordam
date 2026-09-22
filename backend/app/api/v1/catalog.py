import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import delete, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.deps import require_admin
from app.models import Disease, DiseaseMedicine, Medicine, Plant
from app.repositories.catalog_repo import DiseaseRepository, MedicineRepository, PlantRepository
from app.schemas.catalog import (
    DiseaseDetail, DiseaseIn, DiseaseMedicinesIn, DiseaseOut, DiseaseUpdate, MedicineIn, MedicineOut,
    MedicineRecommendation, PlantIn, PlantOut, PlantUpdate,
)

router = APIRouter(tags=["Katalog"])


def _404(what: str):
    return HTTPException(status.HTTP_404_NOT_FOUND, f"{what} topilmadi")


# ---------- Plants ----------
@router.get("/plants", response_model=list[PlantOut])
async def list_plants(q: str | None = None, db: AsyncSession = Depends(get_db)):
    where = [Plant.name.ilike(f"%{q}%")] if q else []
    return await PlantRepository(db).list(*where, order_by=Plant.name, limit=500)


@router.get("/plants/{plant_id}", response_model=PlantOut)
async def get_plant(plant_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    p = await PlantRepository(db).get(plant_id)
    if p is None:
        raise _404("O'simlik")
    return p


async def _disease_out(db: AsyncSession, d: Disease) -> DiseaseOut:
    plant = await db.get(Plant, d.plant_id) if d.plant_id else None
    return DiseaseOut.model_validate(d).model_copy(update={"plant_name": plant.name if plant else None})


@router.get("/plants/{plant_id}/diseases", response_model=list[DiseaseOut])
async def plant_diseases(plant_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    items = await DiseaseRepository(db).list(Disease.plant_id == plant_id, order_by=Disease.name, limit=500)
    return [await _disease_out(db, d) for d in items]


@router.post("/plants", response_model=PlantOut, status_code=201, dependencies=[Depends(require_admin)])
async def create_plant(body: PlantIn, db: AsyncSession = Depends(get_db)):
    p = await PlantRepository(db).create(**body.model_dump())
    await db.commit()
    return p


@router.put("/plants/{plant_id}", response_model=PlantOut, dependencies=[Depends(require_admin)])
async def update_plant(plant_id: uuid.UUID, body: PlantUpdate, db: AsyncSession = Depends(get_db)):
    repo = PlantRepository(db)
    p = await repo.get(plant_id)
    if p is None:
        raise _404("O'simlik")
    await repo.update(p, body.model_dump(exclude_unset=True))
    await db.commit()
    return p


@router.delete("/plants/{plant_id}", status_code=204, dependencies=[Depends(require_admin)])
async def delete_plant(plant_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    repo = PlantRepository(db)
    p = await repo.get(plant_id)
    if p is None:
        raise _404("O'simlik")
    await repo.delete(p)
    await db.commit()


# ---------- Diseases ----------
@router.get("/diseases", response_model=list[DiseaseOut])
async def list_diseases(q: str | None = None, risk_level: str | None = None, db: AsyncSession = Depends(get_db)):
    where = []
    if q:
        where.append(or_(Disease.name.ilike(f"%{q}%"), Disease.symptoms.ilike(f"%{q}%")))
    if risk_level:
        where.append(Disease.risk_level == risk_level)
    items = await DiseaseRepository(db).list(*where, order_by=Disease.name, limit=500)
    return [await _disease_out(db, d) for d in items]


@router.get("/diseases/{disease_id}", response_model=DiseaseDetail)
async def get_disease(disease_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    repo = DiseaseRepository(db)
    d = await repo.get(disease_id)
    if d is None:
        raise _404("Kasallik")
    base = await _disease_out(db, d)
    meds = [MedicineRecommendation.model_validate(m).model_copy(update={"recommendation": r})
            for m, r in await repo.medicines_for(d.id)]
    return DiseaseDetail(**base.model_dump(), medicines=meds)


@router.post("/diseases", response_model=DiseaseOut, status_code=201, dependencies=[Depends(require_admin)])
async def create_disease(body: DiseaseIn, db: AsyncSession = Depends(get_db)):
    try:
        d = await DiseaseRepository(db).create(**body.model_dump())
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Bu ai_label allaqachon mavjud")
    return await _disease_out(db, d)


@router.put("/diseases/{disease_id}", response_model=DiseaseOut, dependencies=[Depends(require_admin)])
async def update_disease(disease_id: uuid.UUID, body: DiseaseUpdate, db: AsyncSession = Depends(get_db)):
    repo = DiseaseRepository(db)
    d = await repo.get(disease_id)
    if d is None:
        raise _404("Kasallik")
    try:
        await repo.update(d, body.model_dump(exclude_unset=True))
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Bu ai_label allaqachon mavjud")
    return await _disease_out(db, d)


@router.delete("/diseases/{disease_id}", status_code=204, dependencies=[Depends(require_admin)])
async def delete_disease(disease_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    repo = DiseaseRepository(db)
    d = await repo.get(disease_id)
    if d is None:
        raise _404("Kasallik")
    await repo.delete(d)
    await db.commit()


@router.put("/diseases/{disease_id}/medicines", response_model=list[MedicineRecommendation], dependencies=[Depends(require_admin)])
async def set_disease_medicines(disease_id: uuid.UUID, body: DiseaseMedicinesIn, db: AsyncSession = Depends(get_db)):
    repo = DiseaseRepository(db)
    if await repo.get(disease_id) is None:
        raise _404("Kasallik")
    for item in body.items:
        if await db.get(Medicine, item.medicine_id) is None:
            raise _404(f"Dori {item.medicine_id}")
    await db.execute(delete(DiseaseMedicine).where(DiseaseMedicine.disease_id == disease_id))
    for item in body.items:
        db.add(DiseaseMedicine(disease_id=disease_id, medicine_id=item.medicine_id, recommendation=item.recommendation))
    await db.commit()
    return [MedicineRecommendation.model_validate(m).model_copy(update={"recommendation": r})
            for m, r in await repo.medicines_for(disease_id)]


# ---------- Medicines ----------
@router.get("/medicines", response_model=list[MedicineOut])
async def list_medicines(q: str | None = Query(default=None), db: AsyncSession = Depends(get_db)):
    where = [Medicine.name.ilike(f"%{q}%")] if q else []
    return await MedicineRepository(db).list(*where, order_by=Medicine.name, limit=500)


@router.get("/medicines/{medicine_id}", response_model=MedicineOut)
async def get_medicine(medicine_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    m = await MedicineRepository(db).get(medicine_id)
    if m is None:
        raise _404("Dori")
    return m


@router.post("/medicines", response_model=MedicineOut, status_code=201, dependencies=[Depends(require_admin)])
async def create_medicine(body: MedicineIn, db: AsyncSession = Depends(get_db)):
    m = await MedicineRepository(db).create(**body.model_dump())
    await db.commit()
    return m


@router.put("/medicines/{medicine_id}", response_model=MedicineOut, dependencies=[Depends(require_admin)])
async def update_medicine(medicine_id: uuid.UUID, body: MedicineIn, db: AsyncSession = Depends(get_db)):
    repo = MedicineRepository(db)
    m = await repo.get(medicine_id)
    if m is None:
        raise _404("Dori")
    await repo.update(m, body.model_dump(exclude_unset=True))
    await db.commit()
    return m


@router.delete("/medicines/{medicine_id}", status_code=204, dependencies=[Depends(require_admin)])
async def delete_medicine(medicine_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    repo = MedicineRepository(db)
    m = await repo.get(medicine_id)
    if m is None:
        raise _404("Dori")
    await repo.delete(m)
    await db.commit()
