# DiaMate demo hesapları

Hepsinin şifresi: **`DiaMate!2026`** (bcrypt olarak saklanır). Şifreyi kurulumda değiştirmek için: `psql -v demo_password='yeni-sifre' ...`. Kurulumdan sonra değiştirmek için:

```sql
UPDATE users SET password_hash = crypt('yeni-sifre', gen_salt('bf', 10)) WHERE is_demo;
```

E-posta alanı `diamate.example` (gerçek bir alan adına gitmez, rezerve edilmiştir).

## Yönetim ve sağlık ekibi

| E-posta | Rol | Not |
|---|---|---|
| `admin@diamate.example` | ADMIN | Kullanıcı yönetimi. Hasta sağlık verisine erişimi **yoktur** (tasarım gereği). |
| `dr.endo@diamate.example` | CLINICIAN | Endokrinoloji. Hasta 01, 02, 03, 06, 07 ile ACTIVE ilişki. |
| `dr.diabetes@diamate.example` | CLINICIAN | Diyabetoloji. Hasta 04, 05, 08 ile ACTIVE ilişki. Hasta 01'e **PENDING** davet, hasta 06 ile **REVOKED** ilişki. |
| `caregiver@diamate.example` | CAREGIVER | Hasta 07 (glukoz, öğün, uyarı; rapor yok) ve hasta 08 (yalnız glukoz ve uyarı; öğün ve rapor yok). |

## Hastalar (8) – gerçek anonim veriden

| E-posta | Tür / tedavi | Kaynak (research.patients) | Son 90 gün verisi (yaklaşık; kurulum saatine göre birkaç satır oynar) |
|---|---|---|---|
| `patient01@diamate.example` | T1 / pompa | HU_0027 (HUPA-UCM) | glukoz 25.874, öğün 155, insülin 258, giyilebilir 25.886 |
| `patient02@diamate.example` | T1 / pompa | HU_0026 (HUPA-UCM) | glukoz 25.703, öğün 45, insülin 217, giyilebilir 25.859 |
| `patient03@diamate.example` | T1 / pompa | HU_0003 (HUPA-UCM) | glukoz 3.711 (13 gün), öğün 65, insülin 108 |
| `patient04@diamate.example` | T1 / pompa | HU_0007 (HUPA-UCM) | glukoz 3.762 (13 gün), öğün 80, insülin 87 |
| `patient05@diamate.example` | T1 / pompa | UC_T1DM_03 (UC_HT_T1DM) | glukoz 1.786 (7 gün), öğün 46, insülin 1.058 |
| `patient06@diamate.example` | T1 / günlük çoklu enjeksiyon | SH1_1006 (Shanghai T1DM) | glukoz 3.770, öğün 123 (yiyecek adı + gram), insülin 152, oral ilaç 108 |
| `patient07@diamate.example` | T2 / karma (insülin + oral) | SH2_2017 (Shanghai T2DM) | glukoz 2.706, öğün 100, insülin 28, oral ilaç 83 |
| `patient08@diamate.example` | T2 / karma, 85 yaş | SH2_2069 (Shanghai T2DM) | glukoz 3.702, öğün 90, insülin 50, oral ilaç 202 |

Glukoz aralığı 40–475 mg/dL. **Tarihler kaydırıldı:** her hastanın en yeni verisi kurulum günüdür (kaynaktaki gerçek tarihler 2018–2022). Günün saati ve okumaların birbirine göre aralığı değişmez, yalnızca takvim günü kaydırılır.

Sentetik olanlar: hasta 01–05'in cinsiyet, yaş, boy, kilo ve hastalık süresi kaynakta olmadığı için demo için uydurulmuştur. Hasta 06–08'inki kaynaktandır.

## Test senaryoları

- **Doktor paneli:** `dr.endo` ile giriş → 5 hasta listelenir (`v_care_team`). `dr.diabetes` hasta 01'i **göremez** (davet bekliyor), hasta 06'yı **göremez** (iptal edildi). `fn_can_access` bunu doğrular.
- **Bakıcı izinleri:** `caregiver` hasta 08'in öğünlerini göremez (`can_view_meals = false`), hasta 07'nin raporlarını göremez.
- **Hasta bazlı eşikler:** hasta 08'in hedef aralığı 90–200, hipo eşiği 80, aciliyet 60/300 (diğerleri 70–180, 70/180, 54/250). Uyarılar `fn_glucose_alert_type` ile bu eşiklere göre üretildi.
- **Uyarılar:** her hastada son 7 günün acil/düşük glukoz uyarıları ve son 2 günün yüksek glukoz uyarıları var (son 24 saat `OPEN`, eskiler `RESOLVED`), ilgili bildirimler ve bakıcı/doktor bildirimleri (yalnız kritik olanlar) dahil.
- **Hatırlatıcılar:** her hastada sabah ve yatmadan glukoz ölçümü, ilaç hatırlatıcıları; son 7 günün `reminder_events` kayıtları (~%85 alındı, gerisi kaçırıldı, bugünün ilerisi `PENDING`). `v_reminder_adherence_30d` uyum yüzdesini verir.
- **Yapay zekâ asistanı:** hasta 01'de "My glucose is 145 before lunch" konuşması ve ondan oluşan `glucose_logs` kaydı (`source = AI_ASSISTANT`).
- **Rapor:** hasta 01'de son 7 günün özet metrikleri `reports.summary` içinde (PDF dosyası yok, yalnız sayılar).
- **Öneri (recommendation):** doktorlardan hastalara 4 örnek metin (okunmuş / okunmamış).

## Demo verisini silmek

```sql
DELETE FROM users WHERE is_demo;   -- hastaya bağlı tüm kayıtlar zincirleme silinir, audit_logs satırları kalır (user_id boşalır)
```

`research` şeması etkilenmez. Demo olmadan kurmak için: `./install_mac.sh --reset --no-demo`.

## Başka bir araştırma hastasını demo yapmak

`patient_profiles` satırı olan bir kullanıcıya, araştırma verisinden son N gün kopyalanabilir:

```sql
SELECT demo_import_research_patient(<user_id>, 'HU_0010', 90, true);   -- (kullanıcı, research.patients.patient_id, gün, tarihleri bugüne kaydır)
```

Uygun hasta bulmak için: `SELECT patient_id, source, diabetes_type FROM research.patients;`
