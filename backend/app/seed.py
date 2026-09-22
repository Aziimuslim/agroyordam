"""Bilimlar bazasi (KB) va demo ma'lumotlar. `python -m app.seed` bilan ham ishga tushadi."""
import asyncio
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models import Comment, Disease, DiseaseMedicine, Like, Medicine, Plant, Post, User

log = logging.getLogger(__name__)

PLANTS = [
    ("Pomidor", "Solanum lycopersicum", "Issiqsevar sabzavot ekini.", "Kuniga 6–8 soat quyosh, ildiz tagidan sug'orish, tayanchga bog'lash."),
    ("Kartoshka", "Solanum tuberosum", "Tugunakli ekin.", "Chopiq va tuproqni ko'mish, o'rtacha namlik."),
    ("Bolgar qalampiri", "Capsicum annuum", "Shirin qalampir.", "Issiq joy, muntazam sug'orish, kaliyli o'g'it."),
    ("Bodring", "Cucumis sativus", "Palakli sabzavot.", "Iliq suv bilan sug'orish, shpalerga ko'tarish."),
    ("Uzum", "Vitis vinifera", "Ko'p yillik mevali o'simlik.", "Kesish, shpaler, zamburug'ga qarshi profilaktika."),
    ("Olma", "Malus domestica", "Mevali daraxt.", "Bahorgi kesish, profilaktik purkash."),
]

MEDICINES = [
    ("Mis oksixlorid", "Mis oksixlorid 90%", "Kontakt fungitsid.", "40 g / 10 l suv, 7–10 kun oralig'ida", "Qo'lqop va niqob taqing; hosildan 20 kun oldin to'xtating.", "Agrokimyo"),
    ("Bordo suyuqligi", "Mis sulfat + ohak", "Keng ta'sirli fungitsid.", "1% eritma, barglarga purkash", "Issiq kunda (30°C+) qo'llamang.", "Mahalliy"),
    ("Oltingugurt kukuni", "Kolloid oltingugurt", "Un shudringga qarshi.", "30 g / 10 l suv, haftada 1 marta", "Harorat 32°C dan oshsa kuydiradi.", "Agrokimyo"),
    ("Mankoseb", "Mankoseb 80%", "Profilaktik fungitsid.", "20–25 g / 10 l suv", "Hosildan 20 kun oldin to'xtating.", "Agrokimyo"),
    ("Trichoderma (bio)", "Trichoderma harzianum", "Biologik fungitsid.", "15 g / 10 l suv, ildiz tagiga", "Kimyoviy fungitsid bilan aralashtirmang.", "BioAgro"),
    ("Bioinsektitsid (Bt)", "Bacillus thuringiensis", "Qurtlarga qarshi biologik vosita.", "20 ml / 10 l suv", "Kechqurun purkang.", "BioAgro"),
]

# (plant, ai_label, name, risk, symptoms, causes, treatment, prevention, [(medicine, recommendation)])
DISEASES = [
    ("Pomidor", "Tomato_Late_blight", "Fitoftoroz (kech kuyish)", "high",
     "Barglarda qo'ng'ir-qora, suvli dog'lar; barg ostida oq g'ubor; poyada jigarrang chiziqlar.",
     "Phytophthora infestans zamburug'simon organizmi; salqin va nam havo.",
     "Zararlangan barglarni darhol olib tashlang va yoqing. Mis oksixlorid bilan 7 kun oralig'ida ishlov bering. Sug'orishni ildiz tagidan qiling.",
     "Almashlab ekish, chidamli navlar, qatorlar orasida havo aylanishi.",
     [("Mis oksixlorid", "40 g / 10 l suv, 3 marta 7 kun oralig'ida"), ("Mankoseb", "Profilaktika uchun")]),
    ("Pomidor", "Tomato_Early_blight", "Alternarioz (erta kuyish)", "medium",
     "Pastki barglarda konsentrik halqali qo'ng'ir dog'lar, atrofi sarg'aygan.",
     "Alternaria solani zamburug'i; issiq va nam sharoit.",
     "Pastki zararlangan barglarni kesing, Mankoseb bilan ishlov bering.",
     "Mulchalash, tomchilatib sug'orish.",
     [("Mankoseb", "25 g / 10 l suv, 10 kun oralig'ida")]),
    ("Pomidor", "Tomato_Bacterial_spot", "Bakterial dog'lanish", "medium",
     "Kichik qora chetli suvli dog'lar barglar va mevalarda.",
     "Xanthomonas bakteriyalari; yomg'ir va purkab sug'orish.",
     "Zararlangan qismlarni olib tashlang, Bordo suyuqligi bilan ishlov bering.",
     "Sog'lom urug', tomchilatib sug'orish.",
     [("Bordo suyuqligi", "1% eritma")]),
    ("Kartoshka", "Potato_Late_blight", "Kartoshka fitoftorozi", "high",
     "Barg chetlarida qoramtir dog'lar, tugunaklarda qattiq jigarrang chirish.",
     "Phytophthora infestans; nam va salqin havo.",
     "Mis oksixlorid bilan ishlov bering, kasal tuplarni olib tashlang.",
     "Sog'lom urug'lik, o'z vaqtida chopiq.",
     [("Mis oksixlorid", "40 g / 10 l suv"), ("Bordo suyuqligi", "1% eritma, profilaktika")]),
    ("Kartoshka", "Potato_Early_blight", "Kartoshka alternariozi", "medium",
     "Barglarda halqasimon qo'ng'ir dog'lar.", "Alternaria solani.",
     "Mankoseb bilan 10 kun oralig'ida ishlov bering.", "Almashlab ekish.",
     [("Mankoseb", "20 g / 10 l suv")]),
    ("Bolgar qalampiri", "Pepper_Bacterial_spot", "Qalampir bakterial dog'i", "medium",
     "Barglarda mayda suvli dog'lar, keyin qo'ng'ir tusga kiradi; barglar to'kiladi.",
     "Xanthomonas bakteriyalari.",
     "Zararlangan barglarni yig'ing, misli preparat bilan ishlov bering.",
     "Tomchilatib sug'orish, sog'lom ko'chat.",
     [("Bordo suyuqligi", "1% eritma"), ("Mis oksixlorid", "30 g / 10 l suv")]),
    ("Bodring", "Cucumber_Powdery_mildew", "Un shudring (kul kasalligi)", "medium",
     "Barg yuzasida oq, un kabi g'ubor; barg sarg'ayib quriydi.",
     "Erysiphales zamburug'lari; kun-tun harorat farqi.",
     "Zararlangan barglarni kesing, oltingugurt eritmasi bilan haftada 1 marta ishlov bering.",
     "Havo aylanishi, azotni me'yorida berish.",
     [("Oltingugurt kukuni", "30 g / 10 l suv")]),
    ("Uzum", "Grape_Black_rot", "Uzum qora chirishi", "high",
     "Barglarda qizg'ish-qo'ng'ir dog'lar, g'ujumlar qorayib burishadi.",
     "Guignardia bidwellii zamburug'i.",
     "Zararlangan g'ujumlarni olib tashlang, Mankoseb/Bordo bilan ishlov bering.",
     "Kuzda to'kilgan barglarni yig'ib yoqish, kesish.",
     [("Mankoseb", "25 g / 10 l suv"), ("Bordo suyuqligi", "Bahorda 1%")]),
    ("Uzum", "Grape_Powdery_mildew", "Uzum oidiumi", "medium",
     "Barg va g'ujumlarda kulrang-oq g'ubor.", "Erysiphe necator.",
     "Oltingugurt preparatlari bilan ishlov bering.", "Tokni siyraklashtirish.",
     [("Oltingugurt kukuni", "30 g / 10 l suv")]),
    ("Olma", "Apple_Scab", "Olma qo'turi (parsha)", "medium",
     "Barg va mevalarda zaytun-qo'ng'ir baxmal dog'lar.", "Venturia inaequalis.",
     "Bordo suyuqligi bilan bahorda ishlov bering.", "To'kilgan barglarni yo'qotish.",
     [("Bordo suyuqligi", "Kurtak bo'rtishida 3%, keyin 1%")]),
    ("Bodring", "Cucumber_Root_rot", "Ildiz chirishi", "high",
     "Ildiz va poya asosi yumshab qorayadi, o'simlik so'liydi.",
     "Fusarium/Pythium; ortiqcha namlik.",
     "Sug'orishni kamaytiring, Trichoderma bilan ildiz tagiga ishlov bering.", "Drenaj, almashlab ekish.",
     [("Trichoderma (bio)", "15 g / 10 l suv, ildiz tagiga")]),
]

DEMO_USERS = [
    ("Dilnoza Karimova", "dilnoza", "dilnoza@agroyordam.uz", "Samarqand"),
    ("Sardor Rahimov", "sardor", "sardor@agroyordam.uz", "Farg'ona"),
]


async def seed_catalog(db: AsyncSession) -> None:
    if await db.scalar(select(Plant.id).limit(1)):
        return
    plants = {}
    for name, sci, desc, care in PLANTS:
        p = Plant(name=name, scientific_name=sci, description=desc, care_info=care)
        db.add(p)
        plants[name] = p
    meds = {}
    for name, ai, desc, usage, prec, man in MEDICINES:
        m = Medicine(name=name, active_ingredient=ai, description=desc, usage=usage, precautions=prec, manufacturer=man)
        db.add(m)
        meds[name] = m
    await db.flush()
    for plant, label, name, risk, sym, cause, treat, prev, links in DISEASES:
        d = Disease(plant_id=plants[plant].id, ai_label=label, name=name, risk_level=risk, symptoms=sym, causes=cause,
                    treatment=treat, prevention=prev, description=sym)
        db.add(d)
        await db.flush()
        for med, rec in links:
            db.add(DiseaseMedicine(disease_id=d.id, medicine_id=meds[med].id, recommendation=rec))
    log.info("KB seed: %d o'simlik, %d kasallik, %d dori", len(PLANTS), len(DISEASES), len(MEDICINES))


async def seed_users(db: AsyncSession) -> None:
    if await db.scalar(select(User.id).where(User.username == "admin")):
        return
    pw = hash_password("Admin12345!")
    db.add(User(full_name="Administrator", username="admin", email="admin@agroyordam.uz", password_hash=pw, role="admin"))
    demo_pw = hash_password("Demo12345!")
    users = []
    for full, uname, email, region in DEMO_USERS:
        u = User(full_name=full, username=uname, email=email, password_hash=demo_pw, region=region)
        db.add(u)
        users.append(u)
    await db.flush()
    p1 = Post(user_id=users[0].id, title="Fitoftorozni mis oksixlorid bilan davoladim", category="experience",
              content="Pomidorimda fitoftoroz chiqqan edi, mis oksixlorid bilan davolayapman. 3-kun bo'ldi, natija yaxshi ko'rinyapti!")
    p2 = Post(user_id=users[1].id, title="Qalampir hosili a'lo", category="advice",
              content="Bog'imdagi qalampirlar sog'lom, hosil bu yil juda yaxshi bo'ldi. Tomchilatib sug'orish katta yordam berdi!")
    db.add_all([p1, p2])
    await db.flush()
    db.add_all([
        Comment(post_id=p1.id, user_id=users[1].id, content="Menda ham xuddi shunday bo'lgan edi, mis oksixlorid haqiqatan yordam beradi."),
        Like(post_id=p1.id, user_id=users[1].id),
        Like(post_id=p2.id, user_id=users[0].id),
    ])


async def run_seed() -> None:
    async with SessionLocal() as db:
        await seed_catalog(db)
        if settings.SEED_DEMO_DATA:
            await seed_users(db)
        await db.commit()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(run_seed())
