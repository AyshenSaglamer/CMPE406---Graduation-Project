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

Kontrol: `curl http://localhost:8080/api/v1/health` → `"status":"UP"`, `curl http://localhost:8080/actuator/health` → `"db":{"status":"UP"}`.

### Yapay zekâ servisi (isteğe bağlı)

`/api/v1/ai/parse`, takımın FastAPI servisine (`ai-service`) bağlanır. Adres `.env` içindeki `AI_SERVICE_BASE_URL` değişkeninden okunur (varsayılan `http://localhost:8000`). Servis çalışmıyorsa backend yine açılır; yalnızca bu endpoint **503** döner.

## 4. Testler

```bash
mvn test        # birim + web katmanı testleri; veritabanı gerekmez
```

Postman: `postman/DiaMate.postman_collection.json` dosyasını içe aktarın ve koleksiyonu baştan sona çalıştırın (*Run collection*). Giriş isteği token'ı `accessToken` değişkenine kaydeder.

## Endpoint'ler

| Metot | Adres | Erişim | Açıklama |
|---|---|---|---|
| GET | `/api/v1/health` | herkese açık | Uygulama ayakta mı |
| GET | `/actuator/health` | herkese açık | Veritabanı bağlantısı dahil sağlık durumu |
| POST | `/api/v1/auth/register` | herkese açık | `{firstName, lastName, email, password, role, dateOfBirth, gender}` → 201. Rol: `PATIENT`, `CAREGIVER`, `CLINICIAN` (`ADMIN` kayıt olamaz). `dateOfBirth` `yyyy-MM-dd`, **en az 16 yaş**. `gender`: `FEMALE`, `MALE`, `OTHER` |
| POST | `/api/v1/auth/login` | herkese açık | `{email, password}` → `{accessToken, tokenType, expiresIn, user}` |
| GET | `/api/v1/users/me` | giriş yapmış herkes | Kendi profili (ad, soyad, e-posta, rol, doğum tarihi, cinsiyet). Kimlik token'dan okunur. |
| GET | `/api/v1/admin/users` | yalnızca `ADMIN` | Hesap listesi; sağlık verisi, doğum tarihi ve cinsiyet **yok** |
| GET | `/api/v1/care-team/patients` | `CLINICIAN`, `CAREGIVER` | Kullanıcıya **ACTIVE** ilişkiyle erişim vermiş hastalar ve izinleri |
| GET | `/api/v1/patients/{patientId}/overview` | hastanın kendisi ya da izinli doktor/bakıcı | Hasta özeti (son glukoz, açık uyarılar). Erişim yoksa **404** (hasta yok ile aynı cevap) |
| POST | `/api/v1/patients/{patientId}/glucose-logs` | yalnızca hastanın kendisi | Glukoz kaydı (mg/dL) → 201 + `Location`. Eşik dışı değer **uyarı** (`alerts`) oluşturur |
| GET | `/api/v1/patients/{patientId}/glucose-logs?from=&to=&page=&size=` | hasta ya da izinli doktor/bakıcı | Yeniden eskiye, sayfalı liste (bkz. aşağıda) |
| GET | `/api/v1/patients/{patientId}/glucose-logs/{logId}` | hasta ya da izinli doktor/bakıcı | Tek kayıt |
| PUT | `/api/v1/patients/{patientId}/glucose-logs/{logId}` | yalnızca hastanın kendisi | Kaydın tamamını değiştirir |
| DELETE | `/api/v1/patients/{patientId}/glucose-logs/{logId}` | yalnızca hastanın kendisi | 204, soft delete (`deleted_at`) |
| | `.../insulin-logs`, `.../meal-logs`, `.../activity-logs` | aynı kurallar | İnsülin, öğün ve aktivite için aynı beş endpoint |
| POST | `/api/v1/ai/parse` | `PATIENT` | `{text}` → yapay zekâ servisinin anladığı kayıtlar. **Hiçbir şey kaydetmez** (bkz. aşağıda) |

Diğer tüm adresler `Authorization: Bearer <accessToken>` ister.

### Yetkilendirme (RBAC)

- **Rol seviyesi:** Token'daki `role` alanı Spring Security'de `ROLE_<rol>` yetkisine çevrilir; endpoint'lerde `@PreAuthorize("hasRole('ADMIN')")` gibi kurallar vardır.
- **Veri seviyesi:** Bir hastanın verisine kimin erişebileceğine veritabanındaki `fn_can_access` fonksiyonu karar verir: hastanın kendisi ya da **ACTIVE**, süresi dolmamış ve ilgili izni olan bakım ilişkisi. `ADMIN` sağlık verisine erişemez.
- **Hata cevapları:** Token yok veya geçersiz → **401**, rol uymuyor → **403**, veri erişimi yok → **404**; hepsi `application/problem+json`.

### Sağlık kayıtları (glukoz, insülin, öğün, aktivite)

| Kayıt | Zaman alanı | Doktor/bakıcının görmesi için izin |
|---|---|---|
| Glukoz | `measurementTime` | `can_view_glucose` |
| İnsülin | `administeredAt` | `can_view_medications` (ayrı bir insülin izni yok) |
| Öğün | `eatenAt` | `can_view_meals` |
| Aktivite | `startedAt` | `can_view_activity` |

- **Yazma:** Şimdilik yalnızca hastanın kendisi yazar. Doktor, bakıcı ve admin yazmaya çalışırsa **403**; hasta başka bir hastanın kayıtlarına yazmaya çalışırsa **404** alır. Kural tek bir yerde (`HealthDataAccess`) tutulur, ileride genişletilebilir.
- **Zamanlar:** ISO-8601, örneğin `2026-10-05T08:30:00Z`. Gelecek zaman kabul edilmez (telefon saati için 5 dakika tolerans var). URL içinde `+03:00` yazılacaksa `+` işareti `%2B` olarak gönderilir.
- **Liste:** `from` ve `to` verilmezse **son 14 gün** listelenir. `size` varsayılanı 50, en fazla 200. Cevap: `{items, page, size, totalElements, totalPages}`.
- **`clientUuid` (isteğe bağlı):** Uygulama her kayıt için bir UUID üretir. Aynı UUID ikinci kez gelirse yeni kayıt açılmaz, mevcut kayıt **200** ile döner. UUID silinmiş bir kayda aitse **409** döner.
- **`source`:** `MANUAL` (varsayılan) ya da `AI_ASSISTANT`. Aktivite tablosu `AI_ASSISTANT` kabul etmediği için aktivite kayıtları her zaman `MANUAL` olarak kaydedilir.
- **Doğrulama:** Sınırlar veritabanındaki CHECK kurallarıyla aynı. Örneğin glukoz 10–600 mg/dL, insülin 0'dan büyük ve en fazla 300 ünite (en fazla 2 ondalık). Hatalı alanlar **400** + `errors: {alan: mesaj}` döner.
- **Uyarı:** Yeni glukoz değeri hastanın eşiklerinin dışındaysa (`fn_glucose_alert_type`) `alerts` tablosuna kayıt eklenir: `URGENT_LOW`/`URGENT_HIGH` → `CRITICAL`, `LOW`/`HIGH` → `WARNING`. Kaydı düzenlemek ya da silmek uyarıyı değiştirmez.

### Yapay zekâ asistanı (`/ai/parse`)

Akış Flutter → backend → FastAPI şeklindedir. Backend, `{text}` alanını servisin `/api/v1/nlp/parse-multiple` endpoint'ine iletir ve şu cevabı döner: `{status, resultCount, results: [{intent, status, value, unit, activity, message}]}`. `intent` alanı `LOG_GLUCOSE`, `LOG_INSULIN`, `LOG_MEAL` ya da `LOG_ACTIVITY` olabilir.

Backend bu sonucu **kaydetmez**. Uygulama sonucu hastaya gösterir; hasta onaylarsa kayıt endpoint'leri `"source": "AI_ASSISTANT"` ile çağrılır. Servis çalışmıyorsa cevap **503**, servis hata döndürürse **502** olur.

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
