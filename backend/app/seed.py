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
    ("Makkajo'xori", "Zea mays", "Don va silos ekini.", "Qator oralarini yumshatish, azotli oziqlantirish, gullash davrida muntazam sug'orish."),
    ("Shaftoli", "Prunus persica", "Danakli mevali daraxt.", "Erta bahorda kesish, kurtak bo'rtishida misli preparat bilan profilaktika."),
    ("Olcha", "Prunus cerasus", "Danakli mevali daraxt.", "Qurigan shoxlarni kesish, tup atrofini toza saqlash."),
    ("Qulupnay", "Fragaria × ananassa", "Ko'p yillik rezavor.", "Mulchalash, gajaklarni olib tashlash, 3–4 yilda joyini almashtirish."),
    ("Qovoq", "Cucurbita spp.", "Palakli poliz ekini.", "Keng oraliq, ildiz tagidan sug'orish, palakni yerga yotqizmaslik."),
]

MEDICINES = [
    ("Mis oksixlorid", "Mis oksixlorid 90%", "Kontakt fungitsid.", "40 g / 10 l suv, 7–10 kun oralig'ida", "Qo'lqop va niqob taqing; hosildan 20 kun oldin to'xtating.", "Agrokimyo"),
    ("Bordo suyuqligi", "Mis sulfat + ohak", "Keng ta'sirli fungitsid.", "1% eritma, barglarga purkash", "Issiq kunda (30°C+) qo'llamang.", "Mahalliy"),
    ("Oltingugurt kukuni", "Kolloid oltingugurt", "Un shudringga qarshi.", "30 g / 10 l suv, haftada 1 marta", "Harorat 32°C dan oshsa kuydiradi.", "Agrokimyo"),
    ("Mankoseb", "Mankoseb 80%", "Profilaktik fungitsid.", "20–25 g / 10 l suv", "Hosildan 20 kun oldin to'xtating.", "Agrokimyo"),
    ("Trichoderma (bio)", "Trichoderma harzianum", "Biologik fungitsid.", "15 g / 10 l suv, ildiz tagiga", "Kimyoviy fungitsid bilan aralashtirmang.", "BioAgro"),
    ("Bioinsektitsid (Bt)", "Bacillus thuringiensis", "Qurtlarga qarshi biologik vosita.", "20 ml / 10 l suv", "Kechqurun purkang.", "BioAgro"),
    ("Abamektin", "Abamektin 1.8% EC", "Kanalar (o'rgimchakkana) va mayda so'ruvchi zararkunandalarga qarshi.", "Yorliqdagi me'yorda (odatda 5–10 ml / 10 l suv), 7–10 kundan so'ng takror", "Asalarilar uchun xavfli — gullash paytida qo'llamang; hosildan kamida 7 kun oldin to'xtating.", "Agrokimyo"),
    ("Tebukonazol", "Tebukonazol 25% EW", "Tizimli fungitsid (zang, dog'lanish, un shudring).", "Yorliqdagi me'yorda (odatda 5–10 ml / 10 l suv)", "Mavsumda 2–3 martadan ko'p qo'llamang (rezistentlik); himoya vositalaridan foydalaning.", "Agrokimyo"),
    ("Azoksistrobin", "Azoksistrobin 25% SC", "Keng ta'sirli tizimli fungitsid.", "Yorliqdagi me'yorda (odatda 6–10 ml / 10 l suv)", "Boshqa guruh fungitsidlari bilan navbatlab ishlating.", "Agrokimyo"),
    ("Imidakloprid", "Imidakloprid 20% SL", "Oqqanot va shira (virus tashuvchilar)ga qarshi insektitsid.", "Yorliqdagi me'yorda (odatda 3–5 ml / 10 l suv)", "Asalarilar uchun juda xavfli; gullayotgan ekinlarga purkamang.", "Agrokimyo"),
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
    ("Pomidor", "Tomato_Leaf_Mold", "Barg mog'ori (kladosporioz)", "medium",
     "Barg ustida och-sariq dog'lar, ostida zaytun-qo'ng'ir baxmal g'ubor; barglar quriydi.",
     "Passalora fulva zamburug'i; issiqxonada yuqori namlik (85%+).",
     "Issiqxonani shamollating, zararlangan barglarni olib tashlang, misli yoki tizimli fungitsid bilan ishlov bering.",
     "Namlikni pasaytirish, pastki barglarni kesish, chidamli navlar.",
     [("Mis oksixlorid", "40 g / 10 l suv"), ("Azoksistrobin", "Yorliq me'yorida")]),
    ("Pomidor", "Tomato_Septoria_leaf_spot", "Septorioz (oq dog'lanish)", "medium",
     "Pastki barglarda mayda, kulrang markazli, qora hoshiyali ko'plab dog'lar.",
     "Septoria lycopersici zamburug'i; nam havo, barglarning ho'llanishi.",
     "Pastki zararlangan barglarni yig'ing, Mankoseb yoki misli preparat bilan 7–10 kun oralig'ida ishlov bering.",
     "Mulchalash, tomchilatib sug'orish, o'simlik qoldiqlarini yo'qotish.",
     [("Mankoseb", "25 g / 10 l suv"), ("Mis oksixlorid", "40 g / 10 l suv")]),
    ("Pomidor", "Tomato_Spider_mites", "O'rgimchakkana", "medium",
     "Barglarda mayda sariq nuqtalar, barg ostida nozik o'rgimchak to'ri; barglar bronza tusga kiradi.",
     "Tetranychus urticae kanasi; issiq va quruq havo.",
     "Barg ostini suv bilan yuving, akaritsid (Abamektin) bilan 7–10 kun oralig'ida 2 marta ishlov bering.",
     "Begona o'tlarni yo'qotish, havo namligini me'yorda ushlash.",
     [("Abamektin", "Yorliq me'yorida, barg ostiga")]),
    ("Pomidor", "Tomato_Target_Spot", "Nishonsimon dog'lanish", "medium",
     "Barglarda konsentrik halqali qo'ng'ir dog'lar, mevada chuqurchali dog'lar.",
     "Corynespora cassiicola zamburug'i; issiq va nam sharoit.",
     "Zararlangan barglarni olib tashlang, Azoksistrobin yoki Mankoseb bilan ishlov bering.",
     "Havo aylanishini yaxshilash, almashlab ekish.",
     [("Azoksistrobin", "Yorliq me'yorida"), ("Mankoseb", "25 g / 10 l suv")]),
    ("Pomidor", "Tomato_Yellow_Leaf_Curl_Virus", "Barg sariq burishish virusi", "high",
     "Yosh barglar sarg'ayib, yuqoriga buraladi, maydalashadi; o'simlik o'sishdan to'xtaydi.",
     "TYLCV virusi; oqqanot (Bemisia tabaci) orqali tarqaladi.",
     "Virusni davolab bo'lmaydi: kasal tuplarni sug'urib yo'qoting, oqqanotga qarshi insektitsid bilan ishlov bering.",
     "Oqqanotga qarshi to'r, sariq yopishqoq tuzoqlar, chidamli navlar.",
     [("Imidakloprid", "Oqqanotga qarshi, yorliq me'yorida")]),
    ("Pomidor", "Tomato_mosaic_virus", "Pomidor mozaika virusi", "high",
     "Barglarda och va to'q yashil mozaika, barg shakli buziladi, hosil kamayadi.",
     "ToMV virusi; qo'l, asbob va urug' orqali yuqadi.",
     "Davosi yo'q: kasal tuplarni yo'qoting, asboblarni dezinfeksiya qiling, qo'lni sovun bilan yuving.",
     "Sog'lom urug', urug'ni termik ishlash, chidamli navlar.",
     []),
    ("Uzum", "Grape_Esca", "Eska (qora qizamiq)", "high",
     "Barg tomirlari orasida sariq-qizg'ish 'yo'lbars' dog'lari, g'ujumlarda qora nuqtalar; tup to'satdan quriydi.",
     "Yog'ochni zararlovchi zamburug'lar kompleksi (Phaeomoniella va b.).",
     "Zararlangan novdalarni sog'lom yog'ochgacha kesing, kesiklarni bog' surkovi bilan yoping; kuchli zararlangan tuplarni almashtiring.",
     "Quruq havoda kesish, katta kesiklarni himoyalash.",
     []),
    ("Uzum", "Grape_Leaf_blight", "Uzum barg dog'lanishi (izariopsis)", "medium",
     "Barglarda noto'g'ri shakldagi to'q qo'ng'ir dog'lar, keyin barg quriydi.",
     "Pseudocercospora vitis zamburug'i.",
     "Mankoseb yoki misli preparat bilan ishlov bering, to'kilgan barglarni yig'ing.",
     "Tokni siyraklashtirish, havo aylanishi.",
     [("Mankoseb", "25 g / 10 l suv"), ("Bordo suyuqligi", "1% eritma")]),
    ("Olma", "Apple_Black_rot", "Olma qora chirishi", "medium",
     "Barglarda binafsha hoshiyali 'qurbaqa ko'zi' dog'lar, mevada qora konsentrik chirish, shoxlarda yaralar.",
     "Botryosphaeria obtusa zamburug'i.",
     "Mumiyolangan mevalar va yarali shoxlarni kesib yo'qoting, fungitsid bilan ishlov bering.",
     "Sanitariya kesish, shikastlanishlarning oldini olish.",
     [("Tebukonazol", "Yorliq me'yorida"), ("Bordo suyuqligi", "Bahorda 1%")]),
    ("Olma", "Apple_Cedar_rust", "Olma zangi", "medium",
     "Barg ustida yorqin sariq-to'q sariq dog'lar, ostida mayda so'rg'ichlar.",
     "Gymnosporangium zamburug'i; archa (qora archa) oraliq xo'jayin.",
     "Bahorda gullashdan oldin va keyin tizimli fungitsid bilan ishlov bering.",
     "Yaqin atrofdagi archalardagi zang o'smalarini olib tashlash, chidamli navlar.",
     [("Tebukonazol", "Yorliq me'yorida")]),
    ("Makkajo'xori", "Corn_Gray_leaf_spot", "Kulrang barg dog'lanishi", "medium",
     "Barg tomirlari bo'ylab cho'zinchoq to'rtburchak kulrang dog'lar.",
     "Cercospora zeae-maydis zamburug'i; issiq, nam havo.",
     "Kasallik erta aniqlansa tizimli fungitsid bilan ishlov bering.",
     "Almashlab ekish, o'simlik qoldiqlarini haydab yuborish, chidamli duragaylar.",
     [("Azoksistrobin", "Yorliq me'yorida")]),
    ("Makkajo'xori", "Corn_Common_rust", "Makkajo'xori zangi", "low",
     "Bargning ikki tomonida qizg'ish-jigarrang chang (so'rg'ich)lar.",
     "Puccinia sorghi zamburug'i; salqin va nam havo.",
     "Kuchli zararlanishda tizimli fungitsid (Tebukonazol) bilan ishlov bering.",
     "Chidamli duragaylar, erta ekish.",
     [("Tebukonazol", "Yorliq me'yorida")]),
    ("Makkajo'xori", "Corn_Northern_Leaf_Blight", "Shimoliy barg kuyishi (gelmintosporioz)", "medium",
     "Barglarda uzun (3–15 sm) kulrang-yashil, keyin qo'ng'ir 'sigara' shaklidagi dog'lar.",
     "Exserohilum turcicum zamburug'i.",
     "Ro'vak chiqarish davrida fungitsid bilan ishlov bering.",
     "Almashlab ekish, qoldiqlarni haydash, chidamli duragaylar.",
     [("Azoksistrobin", "Yorliq me'yorida"), ("Tebukonazol", "Yorliq me'yorida")]),
    ("Shaftoli", "Peach_Bacterial_spot", "Shaftoli bakterial dog'lanishi", "medium",
     "Barglarda mayda burchakli dog'lar, keyin teshiklar paydo bo'ladi; mevada yoriqli dog'lar.",
     "Xanthomonas arboricola pv. pruni bakteriyasi.",
     "Barg to'kilishida va kurtak bo'rtishida misli preparat bilan ishlov bering.",
     "Chidamli navlar, ortiqcha azotdan saqlanish.",
     [("Bordo suyuqligi", "Kurtak bo'rtishida 1–3%"), ("Mis oksixlorid", "40 g / 10 l suv")]),
    ("Olcha", "Cherry_Powdery_mildew", "Olcha un shudringi", "medium",
     "Yosh barg va novdalarda oq un kabi g'ubor; barglar buraladi.",
     "Podosphaera clandestina zamburug'i.",
     "Oltingugurt preparati yoki tizimli fungitsid bilan ishlov bering, zararlangan novdalarni kesing.",
     "Shox-shabbani siyraklashtirish, havo aylanishi.",
     [("Oltingugurt kukuni", "30 g / 10 l suv"), ("Tebukonazol", "Yorliq me'yorida")]),
    ("Qulupnay", "Strawberry_Leaf_scorch", "Qulupnay barg kuyishi", "medium",
     "Barglarda ko'plab mayda binafsha dog'lar, keyin barg chetlari kuygandek quriydi.",
     "Diplocarpon earlianum zamburug'i.",
     "Eski zararlangan barglarni olib tashlang, misli yoki tizimli fungitsid bilan ishlov bering.",
     "Tomchilatib sug'orish, 3–4 yilda plantatsiyani yangilash.",
     [("Mis oksixlorid", "30 g / 10 l suv"), ("Azoksistrobin", "Yorliq me'yorida")]),
    ("Qovoq", "Squash_Powdery_mildew", "Qovoq un shudringi", "medium",
     "Barglarda oq, un kabi dog'lar, keyin butun bargni qoplab quritadi.",
     "Podosphaera xanthii zamburug'i; kun-tun harorat farqi.",
     "Zararlangan barglarni kesing, oltingugurt eritmasi bilan haftada 1 marta ishlov bering.",
     "Keng oraliq, azotni me'yorida berish, chidamli navlar.",
     [("Oltingugurt kukuni", "30 g / 10 l suv")]),
]

DEMO_USERS = [
    ("Dilnoza Karimova", "dilnoza", "dilnoza@agroyordam.uz", "Samarqand"),
    ("Sardor Rahimov", "sardor", "sardor@agroyordam.uz", "Farg'ona"),
]


async def seed_catalog(db: AsyncSession) -> None:
    """Idempotent: mavjud bazaga faqat yetishmayotgan o'simlik/dori/kasalliklarni qo'shadi."""
    plants = {p.name: p for p in (await db.scalars(select(Plant))).all()}
    for name, sci, desc, care in PLANTS:
        if name not in plants:
            plants[name] = Plant(name=name, scientific_name=sci, description=desc, care_info=care)
            db.add(plants[name])
    meds = {m.name: m for m in (await db.scalars(select(Medicine))).all()}
    for name, ai, desc, usage, prec, man in MEDICINES:
        if name not in meds:
            meds[name] = Medicine(name=name, active_ingredient=ai, description=desc, usage=usage, precautions=prec, manufacturer=man)
            db.add(meds[name])
    await db.flush()
    labels = set((await db.scalars(select(Disease.ai_label))).all())
    added = 0
    for plant, label, name, risk, sym, cause, treat, prev, links in DISEASES:
        if label in labels:
            continue
        d = Disease(plant_id=plants[plant].id, ai_label=label, name=name, risk_level=risk, symptoms=sym, causes=cause,
                    treatment=treat, prevention=prev, description=sym)
        db.add(d)
        await db.flush()
        for med, rec in links:
            db.add(DiseaseMedicine(disease_id=d.id, medicine_id=meds[med].id, recommendation=rec))
        added += 1
    if added:
        log.info("KB seed: +%d kasallik (jami %d o'simlik, %d dori)", added, len(plants), len(meds))


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
