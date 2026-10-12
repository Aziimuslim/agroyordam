/// O'zbekiston viloyatlari va ularning tuman/shaharlari.
/// Kalitlar serverda saqlanadigan `region` qiymati bilan bir xil (eski yozuvlar buzilmasin).
const uzRegions = <String, List<String>>{
  'Toshkent shahri': [
    'Bektemir tumani', 'Chilonzor tumani', 'Mirobod tumani', "Mirzo Ulug'bek tumani", 'Olmazor tumani', 'Sergeli tumani',
    'Shayxontohur tumani', 'Uchtepa tumani', 'Yakkasaroy tumani', 'Yangihayot tumani', 'Yashnobod tumani', 'Yunusobod tumani',
  ],
  'Toshkent viloyati': [
    'Bekobod tumani', "Bo'ka tumani", "Bo'stonliq tumani", 'Chinoz tumani', 'Ohangaron tumani', "Oqqo'rg'on tumani",
    'Parkent tumani', 'Piskent tumani', 'Qibray tumani', 'Quyichirchiq tumani', "O'rtachirchiq tumani", 'Yuqorichirchiq tumani',
    'Toshkent tumani', "Yangiyo'l tumani", 'Zangiota tumani',
    'Angren shahri', 'Bekobod shahri', 'Chirchiq shahri', 'Nurafshon shahri', 'Olmaliq shahri', 'Ohangaron shahri', "Yangiyo'l shahri",
  ],
  'Andijon': [
    'Andijon tumani', 'Asaka tumani', 'Baliqchi tumani', "Bo'ston tumani", 'Buloqboshi tumani', 'Izboskan tumani',
    'Jalaquduq tumani', "Xo'jaobod tumani", "Qo'rg'ontepa tumani", 'Marhamat tumani', "Oltinko'l tumani", 'Paxtaobod tumani',
    'Shahrixon tumani', "Ulug'nor tumani", 'Andijon shahri', 'Xonobod shahri',
  ],
  'Buxoro': [
    'Buxoro tumani', "G'ijduvon tumani", 'Jondor tumani', 'Kogon tumani', 'Olot tumani', 'Peshku tumani', "Qorako'l tumani",
    'Qorovulbozor tumani', 'Romitan tumani', 'Shofirkon tumani', 'Vobkent tumani', 'Buxoro shahri', 'Kogon shahri',
  ],
  "Farg'ona": [
    "Bag'dod tumani", 'Beshariq tumani', 'Buvayda tumani', "Dang'ara tumani", "Farg'ona tumani", 'Furqat tumani',
    'Oltiariq tumani', "Qo'shtepa tumani", 'Quva tumani', 'Rishton tumani', "So'x tumani", 'Toshloq tumani',
    "Uchko'prik tumani", "O'zbekiston tumani", 'Yozyovon tumani',
    "Farg'ona shahri", "Marg'ilon shahri", "Qo'qon shahri", 'Quvasoy shahri',
  ],
  'Jizzax': [
    'Arnasoy tumani', 'Baxmal tumani', "Do'stlik tumani", 'Forish tumani', "G'allaorol tumani", "Mirzacho'l tumani",
    'Paxtakor tumani', 'Sharof Rashidov tumani', 'Yangiobod tumani', 'Zafarobod tumani', 'Zarbdor tumani', 'Zomin tumani',
    'Jizzax shahri',
  ],
  'Xorazm': [
    "Bog'ot tumani", 'Gurlan tumani', 'Hazorasp tumani', 'Xiva tumani', 'Xonqa tumani', "Qo'shko'pir tumani", 'Shovot tumani',
    "Tuproqqal'a tumani", 'Urganch tumani', 'Yangiariq tumani', 'Yangibozor tumani', 'Urganch shahri', 'Xiva shahri',
  ],
  'Namangan': [
    'Chortoq tumani', 'Chust tumani', 'Kosonsoy tumani', 'Mingbuloq tumani', 'Namangan tumani', 'Norin tumani', 'Pop tumani',
    "To'raqo'rg'on tumani", "Uchqo'rg'on tumani", 'Uychi tumani', "Yangiqo'rg'on tumani", 'Namangan shahri',
  ],
  'Navoiy': [
    'Karmana tumani', 'Konimex tumani', 'Navbahor tumani', 'Nurota tumani', 'Qiziltepa tumani', 'Tomdi tumani',
    'Uchquduq tumani', 'Xatirchi tumani', 'Navoiy shahri', 'Zarafshon shahri',
  ],
  'Qashqadaryo': [
    'Chiroqchi tumani', 'Dehqonobod tumani', "G'uzor tumani", 'Kasbi tumani', 'Kitob tumani', "Ko'kdala tumani", 'Koson tumani',
    'Mirishkor tumani', 'Muborak tumani', 'Nishon tumani', 'Qamashi tumani', 'Qarshi tumani', 'Shahrisabz tumani',
    "Yakkabog' tumani", 'Qarshi shahri', 'Shahrisabz shahri',
  ],
  "Qoraqalpog'iston": [
    'Amudaryo tumani', 'Beruniy tumani', "Bo'zatov tumani", 'Chimboy tumani', "Ellikqal'a tumani", 'Kegeyli tumani',
    "Mo'ynoq tumani", 'Nukus tumani', "Qanliko'l tumani", "Qo'ng'irot tumani", "Qorao'zak tumani", 'Shumanay tumani',
    "Taxtako'pir tumani", 'Taxiatosh tumani', "To'rtko'l tumani", "Xo'jayli tumani", 'Nukus shahri',
  ],
  'Samarqand': [
    "Bulung'ur tumani", 'Ishtixon tumani', 'Jomboy tumani', "Kattaqo'rg'on tumani", 'Narpay tumani', 'Nurobod tumani',
    'Oqdaryo tumani', 'Pastdarg\'om tumani', 'Paxtachi tumani', 'Payariq tumani', "Qo'shrabot tumani", 'Samarqand tumani',
    'Toyloq tumani', 'Urgut tumani', 'Samarqand shahri', "Kattaqo'rg'on shahri",
  ],
  'Sirdaryo': [
    'Boyovut tumani', 'Guliston tumani', 'Mirzaobod tumani', 'Oqoltin tumani', 'Sardoba tumani', 'Sayxunobod tumani',
    'Sirdaryo tumani', 'Xovos tumani', 'Guliston shahri', 'Shirin shahri', 'Yangiyer shahri',
  ],
  'Surxondaryo': [
    'Angor tumani', 'Bandixon tumani', 'Boysun tumani', 'Denov tumani', "Jarqo'rg'on tumani", 'Muzrabot tumani',
    'Oltinsoy tumani', 'Qiziriq tumani', "Qumqo'rg'on tumani", 'Sariosiyo tumani', 'Sherobod tumani', "Sho'rchi tumani",
    'Termiz tumani', 'Uzun tumani', 'Termiz shahri',
  ],
};

/// "Qoraqalpog'iston, Amudaryo tumani" — bo'sh qismlarsiz.
String placeText(String? region, String? district) => [region, district].whereType<String>().where((s) => s.isNotEmpty).join(', ');
