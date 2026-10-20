# DiaMate Backend

DiaMate, diyabet öz yönetimi ve hasta izleme sistemidir. Bu proje, Flutter mobil uygulamasının (hasta, bakıcı, doktor) konuştuğu **REST API**'dir.

| | |
|---|---|
| Dil / çatı | Java 21, Spring Boot 4.1.1 (Spring MVC, Spring Data JPA / Hibernate 7, Spring Security + JWT, Bean Validation, Actuator) |
| Veritabanı | PostgreSQL 17: takımın ortak veritabanı **Neon** (bulut) ya da yerel Docker (`localhost:5434`); hangisi olduğunu `.env` belirler |
| Build | Maven |
| API | `/api/v1/...`, JSON; hatalar RFC 9457 `application/problem+json` |

## Gereksinimler

- JDK 21 (macOS: `brew install openjdk@21`)
- Docker Desktop (yalnızca yerel veritabanı için)
- `Database` (şema + veri paketi) ve `Dataset` (CSV verileri) klasörleri. **Şimdilik repoda değiller**, takım içinde ayrıca paylaşılır. Aşağıdaki `../Database` yolları, `Database` ve `Dataset` klasörlerini bu `backend` klasörünün yanına koyduğunuzu varsayar.

## 1. Ortam dosyası

```bash
cp .env.example .env
```

`.env` içinde `POSTGRES_PASSWORD` ve `JWT_SECRET` değerlerini doldurun (`JWT_SECRET` için: `openssl rand -base64 64`). `.env` Git'e **girmez**; hem Docker Compose hem Spring Boot bu dosyayı okur.

- **Ortak veritabanı (Neon):** `POSTGRES_HOST`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` Neon'dan alınır ve `POSTGRES_SSLMODE=require` yazılır. Ayrıntılar: `../Database/docs/CLOUD_DB.md` (`../Database/tools/set_env_from_neon.sh` `.env`'i otomatik doldurur). `JWT_SECRET` takımda herkeste aynı olmalı.
- **Yerel veritabanı (Docker):** `.env.example`'daki değerler (`localhost`, `5434`, `prefer`). Ortak veriyi bozmadan deneme yapmak için kullanılır.

## 2. Yerel veritabanını başlatma (Docker, isteğe bağlı)

Neon kullanıyorsanız bu adımı atlayın.

```bash
docker compose up -d        # PostgreSQL 17, localhost:5434
docker compose ps           # STATUS: healthy olmalı
```

**İlk kez kuruluyorsa** (veritabanı boşsa) şemayı ve veriyi yükleyin (~1-2 dk):

```bash
set -a; . ./.env; set +a
cd ../Database
PGPORT=$POSTGRES_PORT PGUSER=$POSTGRES_USER PGDATABASE=$POSTGRES_DB PGPASSWORD=$POSTGRES_PASSWORD ./install_mac.sh
cd ../backend
```

Sonuç: `public` şemasında 30 uygulama tablosu, `research` şemasında 14 veri seti tablosu, 12 demo hesap (bkz. `../Database/docs/DEMO_ACCOUNTS.md`).

### Şema değişiklikleri (Flyway)

`Database` paketinin kurduğu şema **sürüm 1** sayılır. Sonraki değişiklikler `src/main/resources/db/migration/V2__...sql`, `V3__...sql` dosyalarıdır; backend açılırken **Flyway** bunları sırayla ve yalnızca bir kez uygular (kayıt: `flyway_schema_history` tablosu).

| Sürüm | Değişiklik |
|---|---|
| V1 | `Database/sql` paketi (başlangıç noktası) |
| V2 | `users`: `full_name` yerine `first_name` + `last_name` (`full_name` artık bunlardan otomatik üretilir), `date_of_birth` ve `gender` eklendi; bu iki bilgi `patient_profiles`'tan `users`'a taşındı |
| V3 | `users.date_of_birth` için V2'de eklenen "1900-01-01'den sonra olmalı" kısıtı (`users_date_of_birth_check`) kaldırıldı |
| V4 | Profili olmayan her `PATIENT` kullanıcısına `patient_profiles` satırı eklendi (`diabetes_type = 'OTHER'`, eşikler varsayılan). Kayıt sırasında bu satır artık otomatik oluşur; tüm hasta kayıt tabloları bu tabloya bağlıdır |
| V5 | Profili olmayan her `CLINICIAN` kullanıcısına `clinician_profiles` satırı eklendi (`specialization = 'General'`). Kayıt sırasında bu satır artık otomatik oluşur; tedavi planı, reçete ve öneri tabloları bu tabloya bağlıdır (2. hafta, 3. gün) |
| V6 | `activity_logs.source` CHECK kuralına `AI_ASSISTANT` eklendi; aktivite de diğer kayıt türleri gibi Dia'dan geldiğini saklar. Kural yalnızca genişledi, mevcut satırlar etkilenmedi (2. hafta, 4. gün) |
| V7 | `alerts.resolved_by` eklendi: uyarıyı kimin çözdüğü (ilk ele alan `acknowledged_by`'da zaten vardı). Boş olabilir; eski uyarılarda değer yok (2. hafta, 5. gün) |

Uygulanmış bir migration dosyası **değiştirilmez**; yeni bir değişiklik için yeni sürüm dosyası eklenir.

> Backend `.env`'de hangi veritabanı yazıyorsa ona bağlanır ve açılırken eksik migration'ları **o veritabanına** uygular. Ortak Neon veritabanında Flyway herkes için bir kez çalışır; yeni bir migration'ı önce yerel Docker veritabanında deneyin. pgAdmin'deki 5433 ("PostgreSQL 18") kurulumu kullanılmıyor.
> `docker compose down -v` **tüm veriyi siler**; `docker compose stop` ya da `-v` olmadan `docker compose down` veriyi korur.

## 3. Backend'i çalıştırma

- **Eclipse:** `BackendApplication` → *Run As → Java Application*
- **Terminal:**
  ```bash
  export JAVA_HOME=$(/usr/libexec/java_home -v 21)   # ya da JDK 21'in yolu
  mvn spring-boot:run
  ```

Kontrol: `curl http://localhost:8080/api/v1/health` → `"status":"UP"`, `curl http://localhost:8080/actuator/health` → `"status":"UP"` (veritabanına ulaşılamıyorsa `DOWN`).

### Yapay zekâ servisi (isteğe bağlı)

`/api/v1/ai/parse`, takımın FastAPI servisine (`ai-service`) bağlanır. Adres `.env` içindeki `AI_SERVICE_BASE_URL` değişkeninden okunur (varsayılan `http://localhost:8000`). Servis çalışmıyorsa backend yine açılır; yalnızca bu endpoint **503** döner.

## 4. Testler

```bash
mvn test        # birim + web katmanı testleri; veritabanı gerekmez
```

`ProtectedRoutesTest` uygulamadaki tüm endpoint'leri Spring'in kendi listesinden bulur ve her birini token'sız çağırır. Yalnızca `register`, `login` ve `health` 401 dışında bir cevap verebilir. Endpoint sayısı değişirse test kırılır: o zaman testteki sayı, aşağıdaki tablo ve `docs/BACKEND_REVIEW.md` birlikte güncellenir.

Postman: `postman/DiaMate.postman_collection.json` dosyasını içe aktarın ve koleksiyonu baştan sona çalıştırın (*Run collection*). Giriş isteği token'ı `accessToken` değişkenine kaydeder. Postman açmadan terminalden çalıştırmak için (backend `localhost:8080`'de açık olmalı):

```bash
npx -y newman@6.2.1 run postman/DiaMate.postman_collection.json
```

Koleksiyon her çalıştırmada yeni test hesapları açar. Ortak Neon verisini kirletmemek için yerel Docker veritabanında çalıştırın.

`AuthorizationMatrixTest` her endpoint'in hangi rollere açık olduğunu tek bir tabloda tutar ve 4 rolün hepsiyle dener (bkz. [Yetkilendirme](#yetkilendirme-rbac)). Yeni bir endpoint bu tabloya eklenmezse test kırılır.

## 5. Docker imajı

```bash
docker build -t diamate-backend .
```

```bash
docker run --env-file .env -p 8080:8080 diamate-backend
```

İmaj iki aşamada kurulur: Maven ile derleme, sonra yalnızca JRE ile çalıştırma. Uygulama root olmayan `diamate` kullanıcısıyla çalışır ve jar dosyasını değiştiremez. `.env`, `target/`, `Frontend/` ve dokümanlar `.dockerignore` ile imaja girmez; ayarlar yalnızca çalışma anında ortam değişkenleriyle verilir. Container içinden yerel Docker veritabanına bağlanmak için `-e POSTGRES_HOST=host.docker.internal` verilir.

## Endpoint'ler

| Metot | Adres | Erişim | Açıklama |
|---|---|---|---|
| GET | `/api/v1/health` | herkese açık | Uygulama ayakta mı |
| GET | `/actuator/health` | herkese açık | Veritabanı bağlantısı dahil genel durum: `{"status":"UP"}` ya da `DOWN`, yanında yalnızca probe grup adları (`"groups":["liveness","readiness"]`). Bileşen listesi (veritabanı, disk vb.) gösterilmez |
| POST | `/api/v1/auth/register` | herkese açık | `{firstName, lastName, email, password, role, dateOfBirth, gender}` → 201. Rol: `PATIENT`, `CAREGIVER`, `CLINICIAN` (`ADMIN` kayıt olamaz). `dateOfBirth` `yyyy-MM-dd`, **en az 16 yaş**. `gender`: `FEMALE`, `MALE`, `OTHER`. Ad/soyad ve şifre kuralları için bkz. [Güvenlik](#güvenlik) |
| POST | `/api/v1/auth/login` | herkese açık | `{email, password}` → `{accessToken, tokenType, expiresIn, user}`. Üst üste 5 hatalı şifre → hesap 15 dakika kilitlenir (**429**) |
| GET | `/api/v1/users/me` | giriş yapmış herkes | Kendi profili (ad, soyad, e-posta, rol, doğum tarihi, cinsiyet). Kimlik token'dan okunur. |
| GET | `/api/v1/admin/users` | yalnızca `ADMIN` | Hesap listesi; sağlık verisi, doğum tarihi ve cinsiyet **yok** |
| PATCH | `/api/v1/admin/users/{userId}/status` | yalnızca `ADMIN` | `{"active": false}` hesabı hemen durdurur (giriş 403, mevcut token'lar 401); `{"active": true}` açar, örneğin yeni doktoru onaylar. Admin kendi hesabını değiştiremez (**409**). Her değişiklik denetim kaydına yazılır |
| GET | `/api/v1/care-team/patients` | `CLINICIAN`, `CAREGIVER` | Kullanıcıya **ACTIVE** ilişkiyle erişim vermiş hastalar ve izinleri |
| GET | `/api/v1/care-team/alerts?status=&page=&size=` | `CLINICIAN`, `CAREGIVER` | Uyarı paylaşan **tüm** hastaların uyarıları tek istekte, yeniden eskiye. Her öğede hastanın adı ve uyarı (`alert`). `?status=OPEN&size=1` → `totalElements` açık uyarı sayısıdır |
| GET | `/api/v1/patients/{patientId}/overview` | hastanın kendisi ya da izinli doktor/bakıcı | Hasta özeti (son glukoz, açık uyarılar). Erişim yoksa **404** (hasta yok ile aynı cevap) |
| POST | `/api/v1/patients/{patientId}/glucose-logs` | yalnızca hastanın kendisi | Glukoz kaydı (mg/dL) → 201 + `Location`. Eşik dışı değer **uyarı** (`alerts`) oluşturur |
| GET | `/api/v1/patients/{patientId}/glucose-logs?from=&to=&page=&size=` | hasta ya da izinli doktor/bakıcı | Yeniden eskiye, sayfalı liste (bkz. aşağıda) |
| GET | `/api/v1/patients/{patientId}/glucose-logs/{logId}` | hasta ya da izinli doktor/bakıcı | Tek kayıt |
| PUT | `/api/v1/patients/{patientId}/glucose-logs/{logId}` | yalnızca hastanın kendisi | Kaydın tamamını değiştirir |
| DELETE | `/api/v1/patients/{patientId}/glucose-logs/{logId}` | yalnızca hastanın kendisi | 204, soft delete (`deleted_at`) |
| | `.../insulin-logs`, `.../meal-logs`, `.../activity-logs` | aynı kurallar | İnsülin, öğün ve aktivite için aynı beş endpoint |
| GET | `/api/v1/patients/{patientId}/alerts?status=&from=&to=&page=&size=` | hasta ya da uyarı izni olan doktor/bakıcı | Uyarılar, yeniden eskiye, sayfalı (bkz. [Uyarılar](#uyarılar)) |
| GET | `/api/v1/patients/{patientId}/alerts/{alertId}` | hasta ya da uyarı izni olan doktor/bakıcı | Tek uyarı |
| PATCH | `/api/v1/patients/{patientId}/alerts/{alertId}` | hasta ya da uyarı izni olan doktor/bakıcı | `{"status":"ACKNOWLEDGED"}` ya da `{"status":"RESOLVED"}` |
| POST | `/api/v1/ai/parse` | `PATIENT` | `{text}` → yapay zekâ servisinin anladığı kayıtlar. **Hiçbir şey kaydetmez** (bkz. aşağıda) |
| POST | `/api/v1/patients/{patientId}/ai-entries` | yalnızca hastanın kendisi | Hastanın onayladığı `/ai/parse` kayıtlarını `AI_ASSISTANT` kaynağıyla kaydeder → 201 (hepsi daha önce kaydedilmişse 200). Hepsi ya da hiçbiri (bkz. [Yapay zekâ asistanı](#yapay-zekâ-asistanı)) |

Diğer tüm adresler `Authorization: Bearer <accessToken>` ister.

### Yetkilendirme (RBAC)

- **Rol seviyesi:** Token'daki `role` alanı Spring Security'de `ROLE_<rol>` yetkisine çevrilir; endpoint'lerde `@PreAuthorize("hasRole('ADMIN')")` gibi kurallar vardır.
- **Veri seviyesi:** Bir hastanın verisine kimin erişebileceğine veritabanındaki `fn_can_access` fonksiyonu karar verir: hastanın kendisi ya da **ACTIVE**, süresi dolmamış ve ilgili izni olan bakım ilişkisi. `ADMIN` sağlık verisine erişemez.
- **Hata cevapları:** Token yok veya geçersiz → **401**, rol uymuyor → **403**, veri erişimi yok → **404**; hepsi `application/problem+json`.
- **Yetki matrisi** (rol seviyesi; veri seviyesi her satırda ayrıca `fn_can_access`):

| Endpoint'ler | PATIENT | CLINICIAN | CAREGIVER | ADMIN |
|---|---|---|---|---|
| `register`, `login`, `health` (herkese açık) | ✓ | ✓ | ✓ | ✓ |
| `GET /users/me`, `GET /patients/{id}/overview`, kayıtların `GET`'leri, `GET`/`PATCH …/alerts` | ✓ | ✓ | ✓ | ✓ (veri yok → 404) |
| Kayıtların `POST`/`PUT`/`DELETE`'i, `POST /ai/parse`, `POST …/ai-entries` | ✓ | 403 | 403 | 403 |
| `GET /care-team/patients`, `GET /care-team/alerts` | 403 | ✓ | ✓ | 403 |
| `GET /admin/users`, `PATCH /admin/users/{id}/status` | 403 | 403 | 403 | ✓ |

### Hata cevapları

Her hata aynı biçimde döner (RFC 9457, `Content-Type: application/problem+json`):

```json
{"type": "about:blank", "title": "Validation failed", "status": 400, "detail": "One or more fields are invalid",
 "instance": "/api/v1/patients/5/glucose-logs", "errors": {"glucoseValue": "Must be a whole number"}}
```

| Durum | Ne zaman | Gövde |
|---|---|---|
| 400 | Alan kuralı (`@Valid`), yanlış tip, bilinmeyen enum değeri, hatalı tarih, URL'de yanlış tip, metinde kontrol karakteri | `errors: {alan: mesaj}`. Örnek: `"mealContext": "Must be one of: FASTING, BEFORE_MEAL, ..."`, `"dateOfBirth": "Must be a date in yyyy-MM-dd format"`, `"patientId": "Must be a whole number"`, `"notes": "Must not contain control characters"` |
| 405 | Desteklenmeyen HTTP metodu (herkese açık adreslerde de) | `detail` |
| 400 | Gövde JSON değil / gövde yok / nesne yerine dizi | `detail`: `Request body is not valid JSON` / `Request body is required` / `Request body must be a JSON object` |
| 401 | Token yok, geçersiz, süresi dolmuş **ya da hesap pasif veya silinmiş** | `detail`: `Authentication required` / `Invalid or expired access token` |
| 403 | Rol uygun değil; doğru şifreyle giriş ama hesap pasif (onay bekleyen doktor: `This doctor account is waiting for approval by an administrator`) | `detail` |
| 400 | Adres Spring Security'nin güvenlik duvarına takıldı (ör. `;`, `..` ya da `%3B` içeren path) | `detail`: `The request is not valid` (6. gün; önceden Spring Boot'un `timestamp`/`error`/`path` gövdesi). `%00` ve `%2F` içeren adresleri Tomcat, Spring'e gelmeden kısa bir HTML sayfasıyla reddeder |
| 404 | Kayıt yok, erişim yok (ikisi ayırt edilmez), bilinmeyen adres | `detail`: örn. `Patient not found`, `Resource not found` |
| 409 | E-posta zaten kayıtlı; `clientUuid` silinmiş bir kayda ait; çözülmüş/kapatılmış bir uyarının durumu değiştirilmek istendi; admin kendi hesabının durumunu değiştirmek istedi | `detail` |
| 413 | İstek gövdesi 1 MB'tan büyük | `detail`: `Request body must be at most 1 MB` |
| 429 | Hesap kilitli (çok fazla hatalı giriş) | `detail` + `Retry-After: <saniye>` başlığı |
| 500 | Beklenmeyen hata | `detail`: `An unexpected error occurred`. Ayrıntı yalnızca sunucu log'una yazılır |
| 502 / 503 | Yapay zekâ servisi hata döndü / ulaşılamıyor | `detail` |

Tam sayı alanlarına ondalık değer (`"glucoseValue": 120.7`) gönderilirse **400** döner; değer sessizce `120`'ye kesilmez.

### Sağlık kayıtları (glukoz, insülin, öğün, aktivite)

| Kayıt | Zaman alanı | Doktor/bakıcının görmesi için izin |
|---|---|---|
| Glukoz | `measurementTime` | `can_view_glucose` |
| İnsülin | `administeredAt` | `can_view_medications` (ayrı bir insülin izni yok) |
| Öğün | `eatenAt` | `can_view_meals` |
| Aktivite | `startedAt` | `can_view_activity` |

- **Yazma:** Şimdilik yalnızca hastanın kendisi yazar. Doktor, bakıcı ve admin yazmaya çalışırsa **403**; hasta başka bir hastanın kayıtlarına yazmaya çalışırsa **404** alır. Kural tek bir yerde (`HealthDataAccess`) tutulur, ileride genişletilebilir.
- **Zamanlar:** ISO-8601, örneğin `2026-10-05T08:30:00Z`. Gelecek zaman kabul edilmez (telefon saati için 5 dakika tolerans var); 1900'den önceki zaman da kabul edilmez (`Time must not be before the year 1900`). Listelerin `from`/`to`'su 1900–9999 arasında olmalı (`Must be between the years 1900 and 9999`). Önceden veritabanının saklayamadığı bir yıl (ör. `-1000000000`) **500** veriyordu (6. gün). URL içinde `+03:00` yazılacaksa `+` işareti `%2B` olarak gönderilir.
- **Liste:** `from` ve `to` verilmezse **son 14 gün** listelenir. `size` varsayılanı 50, en fazla 200. Cevap: `{items, page, size, totalElements, totalPages}`.
- **`clientUuid` (isteğe bağlı):** Uygulama her kayıt için bir UUID üretir. Aynı UUID ikinci kez gelirse yeni kayıt açılmaz, mevcut kayıt **200** ile döner. Bu, iki istek **aynı anda** gelse de geçerlidir: ikinci istek, aynı `clientUuid` için alınan PostgreSQL advisory lock'unda ilkinin bitmesini bekler ve onun kaydını döner (6. gün; önceden ikincisi 409 alıyordu). UUID silinmiş bir kayda aitse **409** döner (`This clientUuid belongs to a deleted log; send the entry with a new clientUuid`).
- **`source`:** `MANUAL` (varsayılan) ya da `AI_ASSISTANT`, dört türde de. Aktivite V6'dan önce yalnızca `MANUAL` olabiliyordu. `PUT` kaynağı değiştirmez: bir kaydın nereden geldiği sonradan değişmez.
- **Doğrulama:** Sınırlar veritabanındaki CHECK kurallarıyla aynı. Örneğin glukoz 10–600 mg/dL, insülin 0'dan büyük ve en fazla 300 ünite (en fazla 2 ondalık). Hatalı alanlar **400** + `errors: {alan: mesaj}` döner.
- **Öğün silme:** Bir öğün silinince ona bağlı insülin dozlarının `mealLogId`'si `null` olur (aynı transaction'da). Veritabanındaki `ON DELETE SET NULL` yalnızca gerçek silmede çalıştığı için bu iş backend'de yapılır. Silinmiş bir öğüne yeniden bağlamaya çalışmak **400** (`errors.mealLogId`) döner.
- **Uyarı:** Yeni glukoz değeri hastanın eşiklerinin dışındaysa (`fn_glucose_alert_type`) `alerts` tablosuna kayıt eklenir: `URGENT_LOW`/`URGENT_HIGH` → `CRITICAL`, `LOW`/`HIGH` → `WARNING`. Ölçüm silinirse ya da değeri düzeltilirse o ölçümün **açık** (`OPEN`) uyarısı `DISMISSED` olur; düzeltilen değer yeniden kontrol edilir (hâlâ eşik dışındaysa yeni uyarı açılır). Böylece yanlış girilmiş bir değer bakım ekibine sahte bir uyarı olarak kalmaz. `ACKNOWLEDGED`/`RESOLVED` uyarılara dokunulmaz.

### Uyarılar

- **Kim görür:** Hastanın kendisi ya da `can_receive_alerts` izni olan **ACTIVE** bakım ilişkisi (`fn_can_access(..., 'alerts')`). Erişim yoksa **404**; doktor/bakıcının her okuması denetim kaydına yazılır.
- **Liste:** `status` (`OPEN`, `ACKNOWLEDGED`, `RESOLVED`, `DISMISSED`), `from`, `to` isteğe bağlı. Kayıt listelerinden farklı olarak **varsayılan 14 gün sınırı yok**: açık bir uyarı biri ilgilenene kadar listede kalır (overview'daki `openAlerts` sayısıyla aynı). `size` varsayılanı 50, en fazla 200.
- **Durum akışı:** `OPEN` → `ACKNOWLEDGED` → `RESOLVED` (ya da doğrudan `OPEN` → `RESOLVED`). İlk ilgilenen kişi ve zaman `acknowledgedBy`/`acknowledgedAt`'e, çözülme zamanı `resolvedAt`'e yazılır. `DISMISSED` yalnızca backend tarafından verilir (ölçüm silindi/düzeltildi).
- **Hatalar:** `OPEN`/`DISMISSED` istemek → **400**; zaten olan durumu istemek → değişmeden **200** (uygulamanın tekrar denemesi hata sayılmaz); `RESOLVED` ya da `DISMISSED` bir uyarıyı değiştirmek → **409**.
- **Kim değiştirir:** Görenlerle aynı kişiler: hasta ve `alerts` izinli doktor/bakıcı (karar: 12 Ekim 2026). Sağlık kayıtlarını yine yalnızca hasta yazar.
- **Aynı anda değişiklik (5. gün):** Durum tek bir koşullu `UPDATE` ile değişir (`OPEN` → `ACKNOWLEDGED`; `OPEN`/`ACKNOWLEDGED` → `RESOLVED`). İki kişi aynı anda onaylarsa **ilk onaylayan** kaydedilir, ikisi de 200 alır ve aynı sonucu görür. Backend'in araya girip `DISMISSED` yaptığı (ölçüm silindi) bir uyarı yeniden açılmaz, **409** döner.
- **Kim çözdü (V7):** `resolvedBy` ve `resolvedAt`. Doğrudan çözülen uyarıda ilk ele alan da aynı kişi olarak yazılır.
- **Denetim kaydı:** Her durum değişikliği `ALERT_STATUS_CHANGED` olarak yazılır: kim, hangi hasta, hangi uyarı (`entity_id`), eski ve yeni durum (`details`).
- **Bakım ekibi listesi:** `GET /care-team/alerts`, hasta başına ayrı istek yerine tüm hastaların uyarılarını tek istekte verir. Denetim kaydı yalnızca dönen sayfadaki hastalar için yazılır.
- Flutter'daki doktor ve bakıcı uyarı ekranı bu API'yi kullanır (`frontend` dalı, `lib/data/alert_store.dart`).

### Yapay zekâ asistanı

İki adımdır ve FastAPI'nin cevabı **hasta onaylamadan hiçbir zaman kaydedilmez**:

1. `POST /api/v1/ai/parse`: Dia'nın anladıklarını gösterir, hiçbir şey kaydetmez.
2. `POST /api/v1/patients/{patientId}/ai-entries`: Hastanın onayladığı (gerekirse düzelttiği) kayıtları kaydeder.

**1. adım:** Akış Flutter → backend → FastAPI şeklindedir. Backend, `{text}` alanını servisin `/api/v1/nlp/parse-multiple` endpoint'ine iletir ve şu cevabı döner: `{status, resultCount, results: [{intent, status, value, unit, activity, message}], message}`. `intent` alanı `LOG_GLUCOSE`, `LOG_INSULIN`, `LOG_MEAL` ya da `LOG_ACTIVITY` olabilir. Üst düzey `status` hiçbir şey anlaşılmadıysa `UNKNOWN` olur; o zaman sebebi üst düzey `message` alanında yazar.

Backend bu sonucu **kaydetmez**. Servis çalışmıyorsa cevap **503**, servis hata döndürürse **502** olur. Servis yeniden açılınca backend'i yeniden başlatmak gerekmez.

**2. adım:** Uygulama, hastanın onayladığı `SUCCESS` kayıtlarını aynen gönderir; her kayda bir `clientUuid` eklenir:

```json
{"entries": [
  {"intent": "LOG_GLUCOSE", "value": 125.0, "unit": "mg/dL", "clientUuid": "..."},
  {"intent": "LOG_ACTIVITY", "value": 30.0, "unit": "minutes", "activity": "walked", "clientUuid": "..."}]}
```

İsteğe bağlı alanlar: `at` (zaman; verilmezse şimdi), `mealType` (öğün; verilmezse `OTHER`), `mealContext` (glukoz). Backend her kaydı ilgili kayıt türüne çevirir:

| `intent` | Kayıt | Kural |
|---|---|---|
| `LOG_GLUCOSE` | glukoz | Birim `mg/dL` (ya da boş). Dia `125.0` döndürür; tam sayı olarak kaydedilir. `125.5` → 400 (yuvarlanmaz) |
| `LOG_INSULIN` | insülin | Birim `units` (ya da boş). Tip ve uygulama şekli `OTHER` |
| `LOG_MEAL` | öğün | Birim `grams` (ya da boş) → `carbsG`. `mealType` verilmezse `OTHER` |
| `LOG_ACTIVITY` | aktivite | `activity` (ör. `walked`) zorunlu. `minutes` olduğu gibi, `hours` × 60, `seconds` ÷ 60 → `durationMinutes`. `km`, `miles`, `meters`, `repetitions` için süre tahmin edilmez: miktar notlara yazılır (`"5 km"`). Birim yoksa ya da `unspecified` ise (ör. "I walked 30") → 400; uygulama hastaya birimi sormalı |

- **Kurallar:** Kayıt endpoint'lerinin kuralları aynen uygulanır (glukoz 10–600, insülin ≤ 300, gelecek zaman yok, düşük/yüksek glukoz uyarısı). Hatalı kayıt **400** alır ve hata o kaydın adıyla döner, ör. `errors: {"entries[1].value": "Dose must be at most 300 units"}`.
- **Hepsi ya da hiçbiri:** Tek bir kayıt hatalıysa hiçbiri kaydedilmez.
- **Sınırlar ve tekrar gönderim:** En fazla 10 kayıt. Aynı `clientUuid` ile tekrar gönderilen kayıt yeniden kaydedilmez (`created: false`).
- **Yetki:** Yalnızca hasta kaydeder. Doktor, bakıcı ve admin **403**; başka hastanın id'si **404**.
- **AI'ya bağımlı değil:** Bu adım yapay zekâ servisine ihtiyaç duymaz, servis kapalıyken de çalışır.
- **Cevap:** `{savedCount, saved: [{intent, id, created, log}]}`. `log`, ilgili kayıt endpoint'inin cevabıyla aynı biçimdedir.

**Docker:** Docker Compose içinde backend'e `AI_SERVICE_BASE_URL=http://ai-service:8000` verilir; yerelde varsayılan `http://localhost:8000`'dir.

### Güvenlik

- **Giriş kilidi:** Aynı hesaba üst üste **5** hatalı şifre girilirse hesap **15 dakika** kilitlenir. Kilitliyken doğru şifre de kabul edilmez; cevap **429** + `Retry-After` olur. Başarılı giriş sayacı sıfırlar. Kilit yalnızca yeni girişleri durdurur; daha önce alınmış bir token süresi dolana kadar çalışmaya devam eder. Hatalı denemeler veritabanında tek bir `UPDATE ... + 1` ile sayıldığı için paralel denemeler birbirinin sayısını ezemez.
- **Pasif hesap ve rol değişikliği:** Token'ın imzası, süresi ve `iss` alanı doğruysa her istekte hesabın hâlâ aktif olup olmadığı ve rolünün token'daki rolle aynı olup olmadığı da kontrol edilir (tek sorgu). Hesap pasife alınır, silinir ya da rolü değişirse, eski token'lar süreleri dolmadan **hemen 401** almaya başlar.
- **Token nasıl kabul edilir:** Token yalnızca `Authorization: Bearer <token>` başlığından okunur. URL'de (`?access_token=`) gelen token kabul edilmez, çünkü URL'ler sunucu ve proxy log'larına yazılır. `Basic` (kullanıcı adı + şifre) başlığı da kabul edilmez. Başka bir anahtarla imzalanmış, imzasız (`alg: none`), içeriği değiştirilmiş, başka bir `iss` değeri taşıyan ya da `role` alanı olmayan token **401** alır. Bu kurallar `RbacWebTest`'te ve Postman'deki "Auth flow (Week 2 Day 2)" klasöründe denenir.
- **Token içeriği:** `iss`, `sub` (kullanıcı id'si), `role`, `iat`, `exp`. Ad, e-posta ya da sağlık verisi yoktur (`JwtServiceTest`).
- **Süre dolumu:** Token `JWT_EXPIRATION` sonunda geçersiz olur. Spring'in varsayılan **60 saniyelik saat toleransı** yüzünden `exp`'ten sonraki 60 saniye içinde hâlâ kabul edilir; sonra **401** alır. Bu davranış `JWT_EXPIRATION=1m` ile gerçek veritabanında ölçüldü (5. gün).
- **`JWT_SECRET`:** Takımın ortak geliştirme anahtarı `.env` dosyasıyla paylaşılıyor. Bu anahtarı bilen herkes, ortak Neon veritabanındaki her kullanıcı (ADMIN dahil) için geçerli bir token üretebilir. Bu yüzden **üretim ortamı mutlaka ayrı ve yalnızca sunucuda duran bir anahtar** kullanmalı (`openssl rand -base64 64`). Anahtar sızarsa değiştirilmesi yeterlidir: eski anahtarla imzalanmış tüm token'lar o anda geçersiz olur.
- **Doktor onayı (5. gün):** Kayıt formunda herkes `CLINICIAN` seçebildiği için yeni doktor hesabı **pasif** açılır. Giriş, `ADMIN` `PATCH /admin/users/{id}/status` ile onaylayana kadar **403** alır ("waiting for approval"). Hasta ve bakıcı hesapları hemen aktif olur; mevcut doktor hesapları etkilenmedi.
- **Hesabı durdurma:** `ADMIN`, ele geçirilmiş ya da kötüye kullanılan bir hesabı `PATCH /admin/users/{id}/status` ile durdurabilir; hesabın token'ları hemen 401 alır.
- **Herkese açık adreslerde token yok sayılır:** `/auth/register`, `/auth/login` ve `/health` adreslerinde `Authorization` başlığı okunmaz. Böylece uygulama, giriş ekranında süresi dolmuş eski token'ı göndermeye devam etse de giriş yapılabilir.
- **Metin:** JSON'daki tüm metin alanlarında kontrol karakterleri (örn. NUL) reddedilir (**400**). Satır sonu ve tab serbesttir. NUL karakteri PostgreSQL'e yazılamıyordu.
- **JSON'da aynı alan iki kez** (`{"glucoseValue":120,"glucoseValue":600}`) → **400** `errors.glucoseValue: "Must appear only once"` (`spring.jackson.read.strict-duplicate-detection`). Aksi halde bir proxy ya da log ilk değeri, backend ikinciyi görürdü.
- **Sunucunun belirlediği alanlar** (`id`, `patientId`, `enteredBy`, `createdAt`, `deletedAt` …) istek gövdesinde gelirse yok sayılır; hasta id'si URL'den alınıp token'la karşılaştırılır. `source` yalnızca `MANUAL` ya da `AI_ASSISTANT` olabilir (`CGM`, `PUMP` … → 400).
- **Sayılar:** Jackson bir sayıyı en fazla 1000 karakter okur. `ai-entries`'te `value` en fazla 100000 ve 3 ondalık olabilir (5. gün, S-1: `1e999999999` gibi kısa bir sayı dönüşüm sırasında milyar basamaklı bir metne dönüşüp belleği tüketebiliyordu).
- **Sayfa:** `page × size` 2³¹'i geçemez (**400** `errors.page`); önceden çok büyük bir `page` 500 veriyordu (5. gün, S-2).
- **İstek boyutu:** 1 MB'tan büyük gövde okunmadan **413** ile reddedilir. Bu kontrol filtre zincirinin en başında, Spring Security'den önce çalışır; `Content-Length` olmayan isteklerde baytlar okunurken sayılır.
- **Denetim kaydı (`audit_logs`):** `LOGIN`, `LOGIN_FAILED` (sebebiyle: `UNKNOWN_EMAIL`, `WRONG_PASSWORD`, `ACCOUNT_LOCKED`, `ACCOUNT_DISABLED`), `ACCOUNT_LOCKED` ve `VIEW_PATIENT_DATA` olayları yazılır. `VIEW_PATIENT_DATA`, bir hastanın verisini **başka biri** okuduğunda (doktor, bakıcı ya da reddedilen bir deneme) hangi veri türünün okunduğu (`entity_type`) ve sonucuyla (`success`) birlikte kaydedilir. Her kayıtta IP adresi ve User-Agent bulunur. Nginx arkasında gerçek istemci IP'si `X-Forwarded-For` başlığından alınır (`server.forward-headers-strategy: native`). Tomcat bu başlığa yalnızca iç ağdaki bir proxy'den gelirse güvenir, internetten gelen sahte bir başlık dikkate alınmaz. Şifre, token ve sağlık verisi **asla** yazılmaz. Bilinmeyen bir e-postayla yapılan denemede yazılan e-posta da saklanmaz, çünkü kullanıcılar bazen şifrelerini e-posta alanına yazar.
- **Kayıt kuralları:**
  - **Ad ve soyad:** Her dilden harf; aralarında boşluk, kesme işareti (`'` ve `’`), tire ve nokta olabilir (`Ayşe Nur`, `O'Brien`, `Jean-Luc`). Rakam, sembol ve emoji kabul edilmez.
  - **Şifre:** En az 8 karakter ve en fazla 72 byte (BCrypt sınırı). Yaygın şifreler listesinde (`src/main/resources/security/common-passwords.txt`) bulunan şifreler ve e-posta adresinin kendisi reddedilir. Bu kurallar NIST SP 800-63B'yi izler; "büyük harf + rakam + sembol" zorunluluğu yoktur.
- **Başlıklar:** Spring Security varsayılanları açık: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Cache-Control: no-store`.
- **Doğum tarihi:** En az 16 yaş ve en fazla 120 yıl önce (daha eskisi yazım hatası sayılır; 400 + `errors.dateOfBirth`).
- **Çıkış (logout):** Şimdilik yalnızca uygulama tarafında yapılır; uygulama token'ı siler. Sunucu token'ı geri çekemez, bu yüzden token süresi dolana kadar (en fazla 1 saat) geçerli kalır. Hesap pasife alınırsa ya da rolü değişirse token hemen 401 alır. Refresh token ve sunucu tarafında logout 2. haftada yapılmayacak, sonraya bırakıldı (karar: 12 Ekim 2026).
- **Kapsam dışı (sonraki işler):** Refresh token ve sunucu tarafında logout, IP bazlı hız sınırı (Nginx; önerilen ayar `docs/BACKEND_REVIEW.md` bölüm 12'de), 2FA, e-posta doğrulama, doktorun lisansının doğrulanması (şu an admin onayı elle yapılıyor).

## Paket yapısı

```
com.diamate.backend
├── api
│   ├── controller   HTTP katmanı (endpoint'ler)
│   └── dto
│       ├── request  API'ye gelen veriler (doğrulama kuralları burada)
│       └── response API'den dönen veriler
├── service          iş mantığı
├── repository       veritabanı erişimi (Spring Data JPA, yer yer düz SQL)
├── entity           JPA entity'leri (veritabanı tabloları)
├── security         BCrypt, JWT üretimi/doğrulaması, güvenlik kuralları
├── ai               FastAPI yapay zekâ servisine giden HTTP istemcisi
└── exception        uygulama hataları ve merkezi hata yönetimi
```

Veritabanı şeması ve eşleme notları: `../Database/docs/BACKEND_NOTES.md`, `../Database/docs/DATA_DICTIONARY.md`.

Mimari, auth/JWT akışı, endpoint envanteri, test kapsamı ve açık bulgular (2. hafta, 1. gün incelemesi): `docs/BACKEND_REVIEW.md`.
