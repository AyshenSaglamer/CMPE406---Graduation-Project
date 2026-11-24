# DiaMate Backend — Geliştirici Rehberi

Bu rehber DiaMate API'sini kullanacak (mobil uygulama, AI servisleri) ya da backend'e kod ekleyecek takım üyeleri içindir. Kurulum adımları ve endpoint'lerin tam listesi [README](../README.md)'de, güvenlik kararları [SECURITY.md](SECURITY.md)'de, gün gün değişiklikler [BACKEND_REVIEW.md](BACKEND_REVIEW.md)'de.

İçindekiler:

1. [Beş dakikada çalıştırma](#1-beş-dakikada-çalıştırma)
2. [API dokümanı (Swagger / OpenAPI)](#2-api-dokümanı-swagger--openapi)
3. [Kimlik doğrulama: access token, refresh token, logout](#3-kimlik-doğrulama-access-token-refresh-token-logout)
4. [İstek ve cevap kuralları](#4-istek-ve-cevap-kuralları)
5. [Yetki: kim neyi görür](#5-yetki-kim-neyi-görür)
6. [Offline kayıt ve senkron (`clientUuid`)](#6-offline-kayıt-ve-senkron-clientuuid)
7. [Yapay zekâ servisleri](#7-yapay-zekâ-servisleri)
8. [Backend'e yeni bir endpoint eklemek](#8-backende-yeni-bir-endpoint-eklemek)
9. [Veritabanı değişikliği (Flyway)](#9-veritabanı-değişikliği-flyway)
10. [Testler](#10-testler)
11. [Sık karşılaşılan sorunlar](#11-sık-karşılaşılan-sorunlar)

---

## 1. Beş dakikada çalıştırma

**Tam stack (Nginx + backend + PostgreSQL + AI servisleri), repo kökünden:**

```bash
cp .env.example .env              # POSTGRES_PASSWORD, APP_DB_PASSWORD, JWT_SECRET doldurulur
./nginx/make-dev-cert.sh          # yerel CA + sunucu sertifikası (nginx/ssl/)
docker compose up -d --build
curl --cacert nginx/ssl/ca.crt https://localhost:8443/api/v1/health
```

**Yalnız backend (IDE'den), `backend/` klasöründe:** `cp .env.example .env`, ardından `mvn spring-boot:run`. Adres `http://localhost:8080`.

| Ortam | Taban adres | Not |
|---|---|---|
| IDE'den backend | `http://localhost:8080/api/v1` | Swagger açık (`API_DOCS_ENABLED=true`, `backend/.env.example`) |
| Tam stack | `https://localhost:8443/api/v1` | Telefon/simülatör `nginx/ssl/ca.crt`'ye bir kez güvenmeli (iOS: `xcrun simctl keychain booted add-root-cert nginx/ssl/ca.crt`) |
| Android emülatör | `https://10.0.2.2:8443/api/v1` | Emülatörün host'a giden adresi |
| Production | `https://<DOMAIN>/api/v1` | [deploy/DEPLOYMENT.md](../../deploy/DEPLOYMENT.md) |

## 2. API dokümanı (Swagger / OpenAPI)

Backend, controller'lardan OpenAPI 3 açıklamasını kendisi üretir (springdoc). `API_DOCS_ENABLED=true` iken:

- **Swagger UI:** `http://localhost:8080/swagger-ui.html` (tam stack'te `https://localhost:8443/swagger-ui.html`)
- **OpenAPI JSON:** `/v3/api-docs` — Postman'e (*Import → Link*) ya da istemci üreticilerine (`openapi-generator`) verilebilir.

Swagger'da bir isteği denemek için: `POST /api/v1/auth/login` → cevaptaki `accessToken`'ı kopyala → sağ üstteki **Authorize** → yapıştır. Token sayfa açık kaldıkça hatırlanır.

Production'da dokümanlar **kapalıdır** (`docker-compose.prod.yml`, `API_DOCS_ENABLED=false`): API'nin haritasını herkese göstermenin bir faydası yok (OWASP A05).

Ayrıca: Postman koleksiyonu (`postman/DiaMate.postman_collection.json`, her endpoint için çalışan örnek istekler ve testler) ve README'deki endpoint tablosu.

## 3. Kimlik doğrulama: access token, refresh token, logout

```text
POST /auth/login    {email, password}     →  {accessToken, expiresIn, refreshToken, refreshExpiresIn, user}
GET  /...           Authorization: Bearer <accessToken>
POST /auth/refresh  {refreshToken}        →  yeni accessToken + YENİ refreshToken (eskisi artık geçersiz)
POST /auth/logout   Authorization: Bearer <accessToken>   →  204 (bu cihazın oturumu kapanır)
```

| Token | Ömür | Nerede saklanır | Not |
|---|---|---|---|
| Access token (JWT, HS256) | `JWT_EXPIRATION`, varsayılan **15 dk** | Uygulamanın belleği / secure storage | İçinde yalnız `sub` (kullanıcı id), `role`, `sid` (oturum id) var; kişisel veri yok |
| Refresh token | `JWT_REFRESH_EXPIRATION`, varsayılan **30 gün**, her yenilemede baştan başlar | **Yalnız** secure storage (`flutter_secure_storage`) | JWT değil, rastgele 256 bit. Veritabanında yalnız SHA-256'sı var |

Uygulamanın uyması gereken kurallar (Flutter'daki hâli: `lib/services/api_client.dart`):

1. **Refresh token bir kez çalışır.** `/auth/refresh` cevabındaki iki token da saklanır. Eski refresh token tekrar gönderilirse backend bunu çalınmış bir kopya sayar: **oturumu kapatır** (`REFRESH_TOKEN_REUSED` denetim kaydı) ve kullanıcı yeniden giriş yapmak zorunda kalır.
2. **Aynı anda tek yenileme.** Birkaç istek aynı anda 401 alırsa hepsi **aynı** `/auth/refresh` çağrısını beklemeli (yoksa 1. kural yüzünden oturum kapanır). Flutter istemcisi bunu `_refreshing` ile yapar.
3. **401 → bir kez yenile, bir kez tekrar dene.** Yenileme de 401 dönerse oturum bitmiştir: token'lar silinir, giriş ekranına dönülür.
4. **İnternet yokken oturumu silme.** Yenileme isteği ağ hatası verirse token'lar kalır; kayıtlar offline kuyruğa girer (bölüm 6).
5. **Çıkışta `/auth/logout` çağır,** sonra token'ları sil. Çağrı başarısız olsa da telefondaki token'lar silinir.

Bir access token şu durumlarda süresi dolmadan **hemen** 401 alır: oturumu logout edildi, refresh token'ı tekrar kullanıldı, hesap admin tarafından durduruldu, rolü değişti. Bunun için her istekte tek bir küçük sorgu çalışır (`ActiveAccountValidator` → `UserRepository.findRoleForOpenSession`).

Oturumlar `auth_sessions` tablosundadır (V11): bir satır = bir cihazdaki bir giriş. Bir cihazdan çıkış diğer cihazları etkilemez.

## 4. İstek ve cevap kuralları

- **JSON katıdır.** Aynı alanın iki kez gelmesi, yanlış tip (`120` yerine `"120"`, `false` yerine `0`), tam sayı alanında ondalık → **400**; değer sessizce çevrilmez. Sayı, true/false, UUID ve enum alanlarında boş metin `""` de **400**'dür; "yok" için alan hiç gönderilmez ya da `null` gönderilir. Bilinmeyen alanlar yok sayılır.
- **Zamanlar** ISO-8601 (`2026-10-05T08:30:00Z` ya da `+03:00` ile). Tarih `yyyy-MM-dd`. URL içinde `+` → `%2B`.
- **Enum'lar** adıyla: `"mealType": "LUNCH"`.
- **Hatalar** her zaman `application/problem+json`:
  ```json
  {"status": 400, "title": "Validation failed", "detail": "One or more fields are invalid",
   "errors": {"glucoseValue": "Must be a whole number"}}
  ```
  Formda gösterilecek mesaj `errors.<alan>`, genel mesaj `detail`.
- **Durum kodları:** 401 token yok/geçersiz/oturum bitti · 403 rol uygun değil · 404 kayıt yok **ya da** erişim yok (bilerek aynı) · 409 çakışma · 413 gövde çok büyük · 429 çok fazla giriş denemesi (`Retry-After`) · 502/503 AI servisi hata verdi/kapalı.
- **Listeler** sayfalıdır: `?page=0&size=50` (en fazla 200), cevap `{items, page, size, totalElements, totalPages}`. `from`/`to` verilmezse son 14 gün.
- **Gövde sınırı:** 1 MB; ses kaydı 10 MB, yemek fotoğrafı 5 MB.

## 5. Yetki: kim neyi görür

İki katman vardır:

1. **Rol** (`@PreAuthorize`): örneğin kayıt yazmak yalnız `PATIENT`, admin endpoint'leri yalnız `ADMIN`. Uymazsa **403**.
2. **Hangi hasta** (`fn_can_access`, veritabanında): hastanın kendisi ya da hastanın davet edip kabul edilmiş (**ACTIVE**), süresi dolmamış, ilgili izni açık bir doktor/bakıcı. Uymazsa **404**.

İzinler (`care_relationships`): `canViewGlucose`, `canViewMeals`, `canViewMedications` (insülin ve hatırlatıcılar da), `canViewActivity`, `canViewReports`, `canReceiveAlerts`, `canAddRecommendations`. Paylaşım akışı: hasta davet eder (`POST /care-relationships`) → doktor/bakıcı kabul eder (`/{id}/accept`) → hasta izinleri değiştirebilir (`PATCH`) ya da erişimi geri alabilir (`DELETE`). Değişiklik bir sonraki istekte geçerlidir.

Tam tablo: README "Yetkilendirme (RBAC)".

## 6. Offline kayıt ve senkron (`clientUuid`)

Telefon her yeni kayıt (glukoz, insülin, öğün, aktivite) için bir UUID üretir ve `clientUuid` alanında gönderir:

- İlk gönderim → **201** + kayıt.
- Aynı `clientUuid` tekrar gelirse (cevap kaybolduğu için yeniden gönderildi) yeni kayıt açılmaz, mevcut kayıt **200** ile döner. İki istek aynı anda gelse de tek kayıt oluşur.
- UUID silinmiş bir kayda aitse **409**.

Böylece offline kuyruk (`lib/data/offline_queue.dart`) bir kaydı güvenle birden çok kez gönderebilir. Kuyruk, internet gelince token'ı gerekirse yenileyerek (bölüm 3) gönderir.

## 7. Yapay zekâ servisleri

Uygulama AI servislerine **doğrudan bağlanmaz**; her şey backend üzerinden gider (yetki, denetim kaydı ve hata biçimi aynı kalsın diye).

| Backend endpoint'i | Servis | Ne yapar |
|---|---|---|
| `POST /ai/parse`, `POST /ai/voice` | `ai-service` (Ayşen, FastAPI) | Metin/ses → önerilen kayıtlar. **Kaydetmez**; hasta onaylayınca `POST /patients/{id}/ai-entries` |
| `GET /ai/patients/{id}/summary`, `anomaly`, `data-quality`, `drift`, `prediction` | `ai-service` | Hasta geçmişi analizleri |
| `POST /ai/food` | `food-vision-service` (Ayşenur, ResNet50) | Fotoğraf → ilk 3 yemek tahmini + yaklaşık besin değeri. **Kaydetmez**; onaylanan öğün `source: AI_PHOTO` ile kaydedilir |

Servis kapalıysa ilgili endpoint **503** döner, backend'in geri kalanı çalışmaya devam eder. Adresler: `AI_SERVICE_BASE_URL`, `FOOD_VISION_BASE_URL`.

## 8. Backend'e yeni bir endpoint eklemek

Kontrol listesi (testler unutulanı yakalar, ama sırayla gitmek daha hızlı):

1. **DTO'lar** (`api/dto/request`, `api/dto/response`): `record`, Bean Validation ile (`@NotNull`, `@Size`, `@DecimalMin` …). Mesajlar İngilizce ve uygulamada gösterilebilir.
2. **Controller** (`api/controller`): `@PreAuthorize("hasRole('PATIENT')")` gibi rol kuralı. Kullanıcı kimliği her zaman token'dan: `CurrentUser.id(jwt)`; asla gövdeden ya da sorgu parametresinden.
3. **Servis**: hasta verisi okunuyorsa `HealthDataAccess.checkCanRead(viewerId, patientId, PatientDataType.X)`, yazılıyorsa `checkCanWrite`. Erişim yoksa **404** fırlatılır ve denetim kaydına yazılır.
4. **Hata**: yeni bir durum için `exception/` altında bir sınıf ve `GlobalExceptionHandler`'da bir `ProblemDetail`. Hiçbir zaman stack trace ya da SQL mesajı dönmez.
5. **Testler**:
   - `AuthorizationMatrixTest.RULES`'a bir satır (hangi roller) — eklenmezse test kırılır.
   - `ProtectedRoutesTest.ENDPOINT_COUNT` bir artar; herkese açıksa `PUBLIC_ENDPOINTS`'e ve `SecurityConfig.PUBLIC_PATHS`'e eklenir.
   - Servis için birim testi, controller için `@WebMvcTest`; veritabanı sorgusu yeni ise `integration/` altında Testcontainers testi.
6. **Dokümanlar**: README endpoint tablosu, Postman koleksiyonuna istek + test, `BACKEND_REVIEW.md`'de endpoint sayısı. Swagger kendiliğinden güncellenir.

## 9. Veritabanı değişikliği (Flyway)

- Yeni dosya: `src/main/resources/db/migration/V<n>__kisa_aciklama.sql`. **Uygulanmış bir migration asla değiştirilmez.**
- Yeni tablolar için `diamate_app` rolünün yetkileri `Database/sql/10_grants.sql`'deki varsayılan yetkilerden kendiliğinden gelir. `audit_logs` gibi özel bir kural gerekiyorsa migration'a `GRANT`/`REVOKE` yazılır.
- Entity'deki tip, kolonla birebir aynı olmalı: Hibernate açılışta şemayı doğrular (`ddl-auto: validate`); `char(64)` ile `String` uyuşmaz, `varchar(64)` kullanılır.
- Önce yerel veritabanında ve `mvn test` (Testcontainers) ile denenir; ortak Neon veritabanında migration herkes için bir kez çalışır.
- Tam stack'te migration'ları backend değil, ayrı `migrate` servisi sahip hesabıyla uygular.

## 10. Testler

```bash
cd backend && mvn test                              # backend (Docker açıksa veritabanı testleri de)
cd frontend && flutter test                 # mobil uygulama
cd ai-service && python -m pytest -q                # AI servisi
npx -y newman@6.2.1 run postman/DiaMate.postman_collection.json   # API uçtan uca (backend açık olmalı)
python3 tools/api_fuzz_scan.py --base http://localhost:8080/api/v1  # "500 yok" taraması
```

GitHub Actions: `ci.yml` her push/PR'da üç test takımını, `dependency-audit.yml` bağımlılıklardaki bilinen açıkları (OSV-Scanner, pip-audit) çalıştırır; Dependabot haftalık güncelleme PR'ları açar.

## 11. Sık karşılaşılan sorunlar

| Belirti | Sebep / çözüm |
|---|---|
| Her istek 401, token yeni alınmış | Token V11'den önce alınmış (`sid` yok) ya da oturum logout edilmiş → yeniden giriş. `JWT_SECRET` backend'ler arasında farklıysa da olur |
| Uygulama birden giriş ekranına atıyor | Aynı refresh token iki kez gönderildi (iki paralel yenileme). İstemci yenilemeyi tek seferde yapmalı (bölüm 3, kural 2) |
| iOS simülatör "SSL hatası" | Yerel CA simülatöre yüklenmemiş: `xcrun simctl keychain booted add-root-cert nginx/ssl/ca.crt` (sertifikalar `nginx/make-dev-cert.sh` ile üretilir) |
| `/swagger-ui.html` 404 | `API_DOCS_ENABLED=true` değil (tam stack ve production'da varsayılan kapalı) |
| `/ai/food` 503 | `food-vision-service` çalışmıyor ya da model dosyası (`best_resnet50_foodvision.pth`) eksik |
| Giriş 429 | Ya hesap kilitli (5 yanlış şifre, 15 dk) ya da Nginx'in IP başına giriş sınırı (`AUTH_RATE_LIMIT`) |
| Backend açılmıyor: "Schema validation" | Entity ile migration'daki kolon tipi farklı (bölüm 9) |
