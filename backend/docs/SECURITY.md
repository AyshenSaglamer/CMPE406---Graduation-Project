# DiaMate Güvenlik Dokümanı

Sorumlu: **Melih (Backend & Security)**. Durum: 24 Kasım 2026 (refresh token, logout, API dokümanı, bağımlılık taraması ve production kurulumu eklendi).

Bu doküman sistemin **bugünkü** güvenlik durumunu tek yerde anlatır: neyin nasıl korunduğu, bunu hangi testin doğruladığı ve neyin açık kaldığı. Ne zaman ve neden değiştiği `BACKEND_REVIEW.md`'de gün gün yazılıdır: güvenlik bölüm 12, hata yönetimi bölüm 14, OWASP keşif turu ve Postman testleri bölüm 15, AI taşıması bölüm 16. İki doküman çelişirse bu doküman geçerlidir.

Yollar takım reposunun `main` dalına göre yazılmıştır: `backend/`, `ai-service/`, `Database/`, `nginx/`, `.github/workflows/backend-ci.yml`. Melih'in çalışma reposunda (GP) `backend/` klasörünün adı `DiaMate/`'tir.

Bölümler final checklist'in sırasını izler:

1. [Mimari ve güven sınırları](#1-mimari-ve-güven-sınırları)
2. [Kimlik doğrulama ve JWT](#2-kimlik-doğrulama-ve-jwt)
3. [Yetkilendirme (RBAC ve hasta erişimi)](#3-yetkilendirme-rbac-ve-hasta-erişimi)
4. [Paylaşım ve erişimi geri alma](#4-paylaşım-ve-erişimi-geri-alma)
5. [Yapay zekâ entegrasyonu](#5-yapay-zekâ-entegrasyonu)
6. [Denetim kaydı (audit log)](#6-denetim-kaydı-audit-log)
7. [Girdi doğrulama ve hata yönetimi](#7-girdi-doğrulama-ve-hata-yönetimi)
8. [Altyapı: Nginx, Docker, gizli bilgiler](#8-altyapı-nginx-docker-gizli-bilgiler)
9. [OWASP Top 10 eşlemesi](#9-owasp-top-10-eşlemesi)
10. [Doğrulama](#10-doğrulama)
11. [Açık kalanlar](#11-açık-kalanlar)

---

## 1. Mimari ve güven sınırları

```text
Flutter uygulaması
      │  HTTPS (TLS 1.2/1.3), JWT Bearer
      ▼
Nginx  ── host'a açık TEK servis (8443 HTTPS; 8081 yalnız yönlendirir)
      │  Docker ağı (host'a açık değil)
      ▼
Spring Boot backend ── kimlik, yetki, doğrulama, denetim burada
      │                         │
      ▼                         ▼
PostgreSQL                FastAPI AI servisi
(host'a port yok)         (host'a port yok; kendi kimlik doğrulaması yok)
```

- **Güvenilen tek kapı backend'dir.** Uygulama AI servisine ve veritabanına hiçbir zaman doğrudan bağlanmaz. AI servisine giden her istek backend'in yetki kontrolünden geçmiş olur.
- **AI servisinin kendi kimlik doğrulaması yoktur.** Bu bilinçli bir tercih: servis yalnız Docker ağından erişilebilir (`expose`, `ports` yok). Servis ağ dışına açılırsa bu varsayım bozulur (bkz. [11](#11-açık-kalanlar)).
- **Geliştirmede** Flutter uygulaması doğrudan backend'e (`:8080`) bağlanır, Nginx kullanılmaz. Bu yalnız yerel geliştirme içindir.

## 2. Kimlik doğrulama ve JWT

| Konu | Uygulama | Nerede |
|---|---|---|
| Şifre saklama | BCrypt | `SecurityConfig.passwordEncoder` |
| Şifre kuralı | NIST SP 800-63B: en az 8 karakter, yaygın şifre listesinde olamaz, e-postayla aynı olamaz; en fazla 72 bayt (BCrypt sınırı, sessizce kesilmesin diye 400) | `RegisterRequest`, `PasswordPolicy` |
| Kaba kuvvet (hesap) | Art arda 5 yanlış şifre → hesap 15 dk kilitli, `429` + `Retry-After: 900` | `AuthService` |
| Kaba kuvvet (IP) | `POST /auth/login` ve `/auth/register` için IP başına dakikada 10 istek, 5'lik burst; aşılırsa Nginx `429` + `Retry-After: 10` döner. Çok hesaba yayılan denemeleri ve toplu kayıt açmayı yavaşlatır | `nginx/default.conf.template` |
| Kullanıcı sayımı | Bilinmeyen e-posta ile yanlış şifre aynı `401` mesajını alır | `AuthService` |
| Access token | HS256, `iss = diamate-backend`, `sub`, `role`, `sid` (oturum); ömür `JWT_EXPIRATION` (varsayılan **15 dk**, 24 Kasım'a kadar 1 saat) | `JwtService`, `SecurityConfig` |
| Refresh token | 256 bit rastgele (JWT değil), veritabanında yalnız SHA-256'sı (`auth_sessions`, V11). Her kullanımda yenisiyle değişir; son kullanımdan `JWT_REFRESH_EXPIRATION` (30 gün) sonra geçersiz. Değiştirilmiş eski bir token tekrar gelirse oturum kapanır ve `REFRESH_TOKEN_REUSED` yazılır. Aynı token'la aynı anda iki yenileme satır kilidiyle sıraya girer | `AuthSessionService`, `AuthService.refresh` |
| Çıkış | `POST /auth/logout` token'ın oturumunu sunucuda kapatır (`LOGOUT` denetim kaydı); access token süresi dolmadan **hemen** `401`, refresh token geçersiz. Diğer cihazlar etkilenmez | `AuthService.logout`, `RefreshTokenIntegrationTest` |
| Anahtar | `JWT_SECRET` ortam değişkeninden gelir, varsayılan değeri **yoktur**. Yoksa ya da çözüldüğünde 32 bayttan kısaysa uygulama açılmaz | `application.yml`, `SecurityConfig` |
| Token doğrulama | İmza, `exp` (Spring'in 60 sn saat toleransıyla), `iss` ve `role` claim'i kontrol edilir. `alg: none`, başka anahtar, URL'de token (`?access_token=`) ve `Basic` başlığı → `401` | `SecurityConfig`, `RbacWebTest` |
| Pasif hesap, kapanmış oturum | Her istekte tek sorgu: hesap aktif mi, rol token'dakiyle aynı mı, `sid` oturumu açık mı. Admin hesabı durdurursa ya da oturum logout edilirse mevcut token'lar o anda `401` alır, giriş `403`, yenileme `401` | `ActiveAccountValidator`, `UserRepository.findRoleForOpenSession` |
| HTTP oturumu | Sunucuda HTTP oturumu/çerez yok (`STATELESS`); oturum yalnız `auth_sessions` satırı ve token'daki `sid`. CSRF kapalı; bunun sebebi kimliğin çerezle değil `Authorization` başlığıyla taşınması | `SecurityConfig` |
| Herkese açık adresler | Yalnız `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `/api/v1/health`, `/actuator/health`; Swagger (`/swagger-ui.html`, `/v3/api-docs`) yalnız `API_DOCS_ENABLED=true` iken var, production'da kapalı | `SecurityConfig.PUBLIC_PATHS`, `OpenApiConfig` |

**Doktor hesapları (17 Kasım değişikliği):** Admin onayı kaldırıldı, çünkü uygulamada onay ekranı yok. Kendi kaydolan `CLINICIAN` hesabı aktif başlar. Bu hesabın hasta verisine erişebilmesi için hastanın onu davet etmesi gerekir (bölüm 4), bu yüzden onaysız bir doktor hesabı kendi başına hiçbir hasta verisi göremez. Kalan risk: herkes kendini "doktor" olarak tanıtabilir ve hasta bunu ayırt edemez (bkz. [11](#11-açık-kalanlar)).

## 3. Yetkilendirme (RBAC ve hasta erişimi)

Yetki iki katmanda kontrol edilir:

1. **Rol (endpoint seviyesi):** `@PreAuthorize`. Örneğin sağlık kaydı yazmak yalnız `PATIENT`, `/admin/**` yalnız `ADMIN` içindir. Rol uymazsa `403` döner.
2. **Hasta erişimi (veri seviyesi):** Rolü geçen istek için `HealthDataAccess` → veritabanındaki `fn_can_access(viewer, patient, permission)` çalışır. Erişim varsa ya istek sahibi hastanın kendisidir ya da hastayla `ACTIVE` durumda, süresi dolmamış ve ilgili izni veren bir bakım ilişkisi vardır. Erişim yoksa `404` döner, `403` değil: başkasının hasta id'sinin var olup olmadığı da sızmasın diye.

| Rol | Neyi görür | Neyi yazar |
|---|---|---|
| `PATIENT` | Yalnız kendi verisi | Kendi glukoz/insülin/öğün/aktivite kayıtları, kendi uyarıları, bakım davetleri ve izinleri |
| `CAREGIVER`, `CLINICIAN` | Yalnız davetini kabul ettiği hastaların, yalnız izin verilen veri türleri | Sağlık kaydı yazamaz (`403`). `alerts` izni varsa uyarıyı onaylayabilir/çözebilir |
| `ADMIN` | Kullanıcı listesi, hesap durdurma/açma, denetim kayıtları | Hasta sağlık verisini **göremez** (`404`) |

İzin türleri (`PatientDataType` → `care_relationships` kolonları):

| Veri | İzin |
|---|---|
| Glukoz kayıtları, hasta özeti | `glucose` |
| İnsülin kayıtları | `medications` |
| Öğün kayıtları | `meals` |
| Aktivite kayıtları | `activity` |
| Uyarılar | `alerts` |
| AI analizleri (özet, anomali, veri kalitesi, drift, tahmin) | `reports` **ve** `glucose` |

**Nasıl doğrulanıyor:**
- `AuthorizationMatrixTest`, her controller endpoint'ini 4 rolle çağırır. Tabloda karşılığı olmayan yeni bir endpoint eklenirse test kırılır, yani yetkisi tanımlanmamış endpoint kalamaz.
- `HealthDataAccessTest`, `RbacWebTest` ve `CareAccessIntegrationTest` (gerçek PostgreSQL üzerinde `fn_can_access`) veri seviyesindeki kontrolü test eder.

Sağlık kaydını yalnız hastanın yazması geçici bir karardır (5 Ekim). Bakıcının veri girmesi istenirse `HealthDataAccess.checkCanWrite` ve dört `*LogController`'daki `@PreAuthorize` birlikte değişmelidir.

## 4. Paylaşım ve erişimi geri alma

Akış (`/api/v1/care-relationships`):

```text
Hasta davet eder (izinler + isteğe bağlı bitiş tarihi)  →  PENDING
Doktor/bakıcı kabul eder                                →  ACTIVE   (erişim başlar)
          veya reddeder                                 →  DECLINED
Hasta izinleri ya da bitiş tarihini değiştirir          →  ACTIVE   (yeni izinler hemen geçerli)
Hasta veya doktor/bakıcı ilişkiyi bitirir               →  REVOKED  (erişim hemen biter)
Bitiş tarihi geçer                                      →  erişim kendiliğinden biter
```

- **Erişim her istekte yeniden kontrol edilir.** Erişim token'a yazılmaz, her istekte `fn_can_access` ile sorulur. Bu yüzden geri alma ya da izin değişikliği bir sonraki istekte geçerlidir; token'ın süresinin dolmasını beklemek gerekmez. Bitiş tarihi de sorguda kontrol edilir, ayrıca bir zamanlanmış iş yoktur.
- **Pasif hasta:** V8 migration'ı ile pasife alınmış bir hastanın verisine bakım ekibi de erişemez.
- **Kim davet edebilir:** Yalnız hasta, yalnız `CLINICIAN` veya `CAREGIVER` rolündeki aktif hesapları davet edebilir. Reddedilen davet girişimleri denetim kaydına `CARE_INVITE_REFUSED` olarak yazılır.
- **Eşzamanlılık:** İzin güncelleme ve durum geçişleri tek koşullu `UPDATE` ile yapılır. Aynı anda gelen iki istek ilişkiyi tutarsız bırakamaz.
- **Testler:** `CareRelationshipServiceTest` (32 test) ve `CareAccessIntegrationTest` (gerçek veritabanında davet → kabul → erişim → geri alma → 404 ve süre dolumu).

## 5. Yapay zekâ entegrasyonu

| Endpoint | Rol | Veri erişimi |
|---|---|---|
| `POST /ai/parse` (metin → kayıt önerisi, kaydetmez) | `PATIENT` | Yok (yalnız gönderilen metin) |
| `POST /ai/voice` (ses → kayıt önerisi, kaydetmez) | `PATIENT` | Yok |
| `POST /ai/food` (yemek fotoğrafı → tahmin + yaklaşık besin değeri, kaydetmez) | `PATIENT` | Yok (yalnız gönderilen fotoğraf ve `food_catalog`) |
| `POST /patients/{id}/ai-entries` (onaylanan öneriyi kaydeder) | `PATIENT` (kendisi) | Kayıt yazma kuralları |
| `GET /ai/patients/{id}/summary`, `anomaly`, `data-quality`, `drift`, `prediction` | Herkes (rol) | `reports` + `glucose` izni, yoksa `404`; her okuma denetime yazılır |

- **AI servisi kapalı ya da yavaşsa:** Bağlantı için 2 sn, okuma için 10 sn (ses için 60 sn) zaman aşımı var. Aşılırsa `503 "The AI service is currently unavailable"` döner.
- **AI servisinden bozuk cevap gelirse:** `502`. AI servisi veriyi yetersiz bulursa (`422`) kendi açıklaması kullanıcıya aynen iletilir.
- **İç bilgi sızmaz:** AI servisinin hata gövdesi, stack trace'i ve iç adresi hiçbir zaman kullanıcıya gönderilmez.
- **Gönderilen veri sınırlı:** En fazla 31 günlük pencere ve tür başına en fazla 10 000 kayıt gönderilir. Öğün ve aktivite yalnız izleyenin görme izni varsa eklenir.
- **Ses dosyası:** Boş olamaz, en fazla 10 MB. Tür dosya uzantısından belirlenir (`.wav`, `.mp3`, `.m4a`, `.webm`, `.ogg`); bildirilen MIME türü açıkça başka bir şeyse (resim, PDF) reddedilir. Hepsinde `400` ve `errors.audio` döner. AI servisine dosya her zaman sabit bir adla gönderilir, kullanıcının verdiği ad kullanılmaz.
- **Yemek fotoğrafı (`food-vision-service`):** Fotoğraf backend'de kontrol edilir. Türüne ilk baytlar karar verir (JPG/PNG/WEBP), adı ya da bildirilen türü değil. Boş dosya, 5 MB'tan büyük dosya ve başlığında 50 megapikselden büyük resim bildiren JPG/PNG (decompression bomb) servise gönderilmeden `400` + `errors.image` alır. Servise sabit bir ad gider. Fotoğraf backend'de yalnız bellekte tutulur, servisin `/predict-food` ucu da diske yazmaz. Servisin eski `/upload-image` ucu her fotoğrafı diske yazıyor (F-2), backend onu çağırmaz. Servisin cevabı da kontrol edilir (en az bir tahmin, güven 0–1, sınıf adı `[a-z0-9_]`); uymazsa `502`. Bağlantı için 2 sn, cevap için 30 sn beklenir; servis kapalıysa `503`. Tahminler hastaya onaylatılır, besin değerleri kaba tahmindir ve cevaptaki `note` doz hesabında kullanılmamalarını söyler.
- **Tıbbi sınır:** AI çıktıları teşhis ya da doz önerisi değildir. Bu sorumluluk AI servisinin dokümanındadır (`ai-service/docs/AI_SERVICE_GUIDE.md`, "AI Safety").

Testler: `AiClientTest`, `AiServiceTest`, `AiVoiceWebTest`, `AiEntryWebTest`, `FoodVisionClientTest`, `FoodRecognitionServiceTest`, `AiFoodWebTest`, `FoodCatalogIntegrationTest` ve `AuthorizationMatrixTest`'teki AI satırları. Uçtan uca (23 Kasım, tam stack): beş analiz `200`; AI servisi durdurulunca `503`; gerçek bir ses kaydı 2 sn'de doğru çözümlendi.

## 6. Denetim kaydı (audit log)

Kayıtlar `audit_logs` tablosuna yazılır. Her satırda işlemi yapan kullanıcı, ilgili hasta, işlem, zaman ve IP adresi bulunur.

| İşlem | Ne zaman |
|---|---|
| `REGISTER` | Kayıt |
| `LOGIN` / `LOGIN_FAILED` (`UNKNOWN_EMAIL`, `WRONG_PASSWORD`, `ACCOUNT_LOCKED`, `ACCOUNT_DISABLED`) | Her giriş denemesi |
| `ACCOUNT_LOCKED` | 5. yanlış şifre |
| `ACCOUNT_STATUS_CHANGED` | Admin bir hesabı durdurur veya açar |
| `ACCESS_DENIED` | Rolü uymayan istek (`403`) |
| `VIEW_PATIENT_DATA` | Hasta verisinin her okunması; reddedilen denemeler de yazılır (`allowed=false`). AI analizleri de buna dahil |
| `HEALTH_LOG_UPDATED`, `HEALTH_LOG_DELETED` | Sağlık kaydının değiştirilmesi ve silinmesi. Yeni kayıt denetime yazılmaz; kimin ve ne zaman eklediği kaydın kendisinde durur (`entered_by`, `created_at`) |
| `ALERT_STATUS_CHANGED` | Uyarının onaylanması veya çözülmesi |
| `CARE_INVITED`, `CARE_ACCEPTED`, `CARE_DECLINED`, `CARE_PERMISSIONS_CHANGED`, `CARE_REVOKED`, `CARE_INVITE_REFUSED` | Paylaşım akışının her adımı |
| `AUDIT_LOG_VIEWED` | Admin denetim kayıtlarını okur |

**Denetim kayıtlarını okuma:**
- `GET /patients/{id}/access-log`: hasta, verisine kimin baktığını görür.
- `GET /admin/audit-logs`: admin tüm kayıtları görür; bu okuma da denetime yazılır.

**IP adresi:** Nginx `X-Forwarded-For` başlığını istemcinin gönderdiği değerin üzerine yazar. Bu sayede istemci sahte bir IP gönderse bile o IP denetim kaydına geçmez (23 Kasım'da sahte `10.9.9.9` ile denendi).

**Değiştirilemezlik:** `audit_logs` yalnız eklemeye açıktır. İki trigger (`trg_audit_logs_row`, `trg_audit_logs_trunc`; `Database/sql/06_app_schema.sql`) `UPDATE`, `DELETE` ve `TRUNCATE`'i reddeder. Tek istisna, silinen bir kullanıcının satırlardan ayrılmasıdır (`user_id → NULL`). Trigger veritabanı sahibi dahil herkese uygulanır. Ayrıca `10_grants.sql`, `diamate_app` rolünden bu yetkileri alır. Trigger'ı yalnız tablonun sahibi kapatabilir. Tam stack'te backend `diamate_app` ile bağlandığı için bunu yapamaz (bölüm 8, "Veritabanı hesapları").

`/ai/parse` ve `/ai/voice` denetime yazılmaz: hasta verisi okumazlar ve bir şey kaydetmezler. Kaydedilen öneri (`ai-entries`) normal bir sağlık kaydıdır; `source = AI_ASSISTANT` alanı onun yapay zekâdan geldiğini gösterir.

Testler: `AuditServiceTest`, `AuditLogServiceTest`, `HealthDataAccessTest`, `CareRelationshipServiceTest`.

## 7. Girdi doğrulama ve hata yönetimi

**Girdi doğrulama**

| Kural | Davranış |
|---|---|
| Bean Validation | Her istek DTO'sunda alan sınırları vardır (ör. glukoz 10–600 mg/dL, not ≤ 1000 karakter); ihlal → `400` ve `errors.<alan>` |
| Katı JSON | Aynı alanın iki kez gelmesi, yanlış JSON tipi (`"120"` sayı değil; `0` boolean değil), sayı/boolean/enum yerine boş metin, ondalık değerin tam sayıya kesilmesi ve 1000 karakterden uzun sayı → `400`. Bilinmeyen alanlar hata vermez, yok sayılır |
| Sunucunun belirlediği alanlar | `id`, `patientId`, `enteredBy`, `createdAt` gövdede gelse de yok sayılır; hasta ve yazan token'dan alınır |
| Zaman | Kesin ISO-8601 `Instant`; gelecekteki ölçüm → `400`; `from`/`to` aralığı sınırlı |
| Sayfalama | `page × size` taşmaz (`400`) |
| Gövde boyutu | 1 MB (`RequestSizeLimitFilter`), `/ai/voice` için 11 MB; Nginx sınırı da 11 MB |
| SQL | Yalnız parametreli sorgu (JPA / `@Query`). SQL'e benzeyen metin notta olduğu gibi saklanır |

**Hata yönetimi**

- Her hata `application/problem+json` biçiminde döner: `title`, `status`, `detail`, `instance` ve gerekirse `errors`.
- Bu biçim Spring Security'nin `401`/`403` cevapları (`ProblemDetailSecurityHandler`), controller'a ulaşmadan reddedilen istekler (`ProblemErrorController`) ve Nginx'in kendi `413`/`429`/`503` cevapları için de geçerlidir.
- Beklenmeyen hatalar `500 "An unexpected error occurred"` döner. Stack trace, SQL ya da sınıf adı kullanıcıya gönderilmez; ayrıntı yalnız sunucu log'una yazılır.

| Durum | Cevap |
|---|---|
| Token yok / geçersiz / süresi dolmuş | `401` |
| Yanlış rol | `403` |
| Yetkisiz `patientId` veya var olmayan kayıt | `404` |
| Eksik/yanlış alan, `null` zorunlu alan, bozuk JSON | `400` |
| Çok büyük gövde | `413` |
| Hesap kilitli | `429` + `Retry-After: 900` (backend) |
| Bir IP'den çok fazla giriş/kayıt denemesi | `429` + `Retry-After: 10` (Nginx) |
| AI servisi yok / bozuk cevap | `503` / `502` |
| Backend çalışmıyor (Nginx) | `503` |
| Beklenmeyen hata | `500` (ayrıntısız) |

Testler: `StrictJsonWebTest`, `InputHardeningWebTest`, `LogEndpointsWebTest`, `ProblemErrorControllerTest`, `RequestSizeLimitFilterTest`.

## 8. Altyapı: Nginx, Docker, gizli bilgiler

**Nginx** (`nginx/default.conf.template`)
- `80` portu yalnız `308` ile HTTPS'e yönlendirir. 308 kullanıldığı için POST, POST olarak kalır ve JWT hiçbir zaman düz HTTP ile backend'e gitmez. Tek istisna Let's Encrypt doğrulama dosyaları (`/.well-known/acme-challenge/`); geliştirmede bu klasör boştur.
- TLS 1.2/1.3. HSTS (`max-age=31536000`) Nginx'in kendi hata cevaplarında da gönderilir. `server_tokens off`.
- Gövde sınırı 11 MB; okuma zaman aşımı 90 sn (ses isteği için); backend'e bağlantı zaman aşımı 5 sn.
- `X-Forwarded-For` istemcinin değerine eklenmez, üzerine yazılır (bölüm 6).
- **Giriş/kayıt için hız sınırı:** yalnız `POST /auth/login` ve `/auth/register` (24 Kasım'dan beri `/auth/refresh` ve `/auth/logout` sınır dışı: uygulama yenilemeyi kendisi yapar ve aynı NAT'taki kullanıcılar birbirinin giriş kotasını tüketmemeli; refresh token 256 bit olduğu için tahmin edilemez). `limit_req`, IP başına `AUTH_RATE_LIMIT` (varsayılan `10r/m`) ve `AUTH_RATE_BURST` (varsayılan `5`); ikisi de `.env`'den değiştirilebilir. Diğer endpoint'ler sınırlanmaz. Backend'in kendi `429`'u (hesap kilidi) Nginx'ten değişmeden geçer.
  - Aynı IP'yi paylaşan kullanıcılar (ör. aynı NAT arkasındaki bir okul ağı) aynı kotayı paylaşır. Demo sırasında sorun olursa `AUTH_RATE_LIMIT` artırılabilir.
  - Docker Desktop (macOS) bütün istemcileri aynı IP (`192.168.65.1`) ile gösterdiği için yerelde herkes tek kotayı paylaşır.

**Production** (`docker-compose.prod.yml`, `deploy/DEPLOYMENT.md`, 24 Kasım)
- Gerçek alan adı ve **Let's Encrypt** sertifikası: ilk sertifikayı `deploy/init-letsencrypt.sh` alır, `certbot` servisi günde iki kez kontrol edip 30 günden az kaldığında yeniler, Nginx 6 saatte bir yeniden yüklenir. Sertifika ve sunucu adı `.env`'deki `DOMAIN`'den gelir (`SSL_CERTIFICATE`, `SERVER_NAME`).
- Standart portlar (80/443), Swagger kapalı (`API_DOCS_ENABLED=false` zorlanır), `JWT_SECRET` yalnız sunucuda.
- Gece yedeği: `deploy/backup-db.sh` (`pg_dump`, gzip, `600` izinli dosya, son 14 tane). Geri dönüş adımları rehberde.
- **Durum:** Hazır ama henüz bir sunucuya kurulmadı (alan adı ve sunucu Ayşen'le seçilecek). Yerelde doğrulanan: compose birleştirmesi (`docker compose config`) ve Nginx şablonu (`nginx -t`, iki sertifika yoluyla).

**Docker Compose** (`docker-compose.yml`)
- Host'a yalnız Nginx açılır. Backend, AI servisi ve PostgreSQL yalnız Docker ağında çalışır.
- `POSTGRES_PASSWORD`, `APP_DB_PASSWORD` ve `JWT_SECRET` `.env`'den gelir. Verilmezse compose çalışmaz (`${VAR:?}`).
- Boş veritabanı ilk açılışta `Database/sql` betikleriyle kurulur; ardından `Database/docker/08_app_role_login.sql`, `diamate_app` rolüne `APP_DB_PASSWORD` ile giriş izni verir.

**Veritabanı hesapları (en az yetki)**

| Hesap | Kim kullanır | Ne yapabilir |
|---|---|---|
| Sahip (`POSTGRES_USER`, `POSTGRES_PASSWORD`) | Yalnız `migrate` servisi (`flyway/flyway:12.4.0`): migration'ları uygular ve kapanır | Her şey (şema, roller, trigger'lar) |
| `diamate_app` (`APP_DB_PASSWORD`) | Çalışan backend (`SPRING_FLYWAY_ENABLED=false`) | `public` tablolarında `SELECT/INSERT/UPDATE/DELETE`, `research` için yalnız `SELECT`, fonksiyon çağırma. `audit_logs` için yalnız `INSERT` ve `SELECT` |

- **Backend sahibin şifresini hiç bilmez.** Backend ele geçirilse bile tablo silinemez veya değiştirilemez, rol oluşturulamaz, `audit_logs` güncellenemez/silinemez ve trigger'ı kapatılamaz.
- **Migration geçmişi:** `afterMigrate__revoke_app_access_to_flyway_history.sql` callback'i her migration'dan sonra `flyway_schema_history` üzerindeki bütün yetkileri `diamate_app`'ten alır. Bu callback olmasaydı `10_grants.sql`'deki varsayılan yetkiler o tabloyu da kapsardı. Callback rol yoksa bir şey yapmaz.
- **Kapsam:** Bu ayrım yalnız tam stack'te (compose) geçerlidir. IDE ile ortak Neon veritabanına bağlanırken backend hâlâ `.env`'deki tek kullanıcıyla bağlanır ve migration'ları kendisi uygular (bkz. S-A).
- **Eski volume:** Bu değişiklikten önce oluşturulmuş bir veritabanı volume'unda rol bir kez elle açılmalıdır: `docker compose exec database psql -U diamate -d diamate -c "ALTER ROLE diamate_app LOGIN PASSWORD '<APP_DB_PASSWORD>'"`.
- **Doğrulama (23 Kasım, boş veritabanıyla tam stack):** Backend'in bütün bağlantıları `diamate_app` ile açık. Bütün migration'ları sahip hesabı uyguladı. Kayıt, giriş, glukoz POST/PUT/DELETE, AI özeti ve erişim geçmişi çalışıyor; denetim kayıtları yazılıyor. `diamate_app` ile `DROP TABLE`, `CREATE TABLE`, `ALTER TABLE`, trigger kapatma, `audit_logs` üzerinde `UPDATE`/`DELETE`/`TRUNCATE`, `CREATE ROLE` ve `flyway_schema_history`'yi okuma/silme reddedildi.
- **Backend imajı:** İki aşamalı derleme; çalışma aşamasında yalnız JRE var. Uygulama root olmayan `diamate` kullanıcısıyla çalışır, jar salt okunurdur ve imajın içinde `.env` dosyası yoktur.

**Gizli bilgiler**
- `.env`, `.env.*` (`.env.example` hariç), `ssl/`, `*.key` ve `*.pem` Git'e girmez (`.gitignore`). Docker build context'ine de girmez (`.dockerignore`).
- Repoda yalnız yer tutucu değerler vardır (`change-me`). 23 Kasım'da iki reponun (GP ve takım reposu) bütün dallarının geçmişi bilinen kalıplarla tarandı ve gerçek bir anahtar ya da şifre bulunmadı. Taranan kalıplar: özel anahtar, AWS/GitHub/OpenAI token'ları, Neon şifresi, şifre içeren veritabanı adresi, 16+ karakterlik `SECRET`/`PASSWORD` değerleri. Bu tarama kalıp tabanlıdır, tam bir gizli bilgi tarayıcısı değildir.
- Geliştirme sertifikası `nginx/make-dev-cert.sh` ile üretilir: yerel küçük bir CA (`ca.crt`) ve onun imzaladığı sunucu sertifikası (`serverAuth`, CA bayrağı yok, 1 yıl). Telefon/simülatör yalnız CA'ya bir kez güvenir. iOS, `serverAuth` içermeyen sunucu sertifikasını reddettiği için önceki kendinden imzalı sertifikayla uygulama bağlanamıyordu (23 Kasım'da simülatörde bulundu). Üretimde gerçek bir CA sertifikası aynı dosya adlarıyla (`server.crt`, `server.key`) konur.

## 9. OWASP Top 10 eşlemesi

| OWASP (2021) | Önlem | Bölüm |
|---|---|---|
| A01 Broken Access Control | İki katmanlı yetki; erişim her istekte yeniden kontrol; yetkisiz hasta için `404`; yetki matrisi testi | 3, 4 |
| A02 Cryptographic Failures | BCrypt; HS256 ve en az 32 baytlık anahtar; TLS 1.2+ ve HSTS | 2, 8 |
| A03 Injection | Parametreli sorgu; katı JSON; tip ve uzunluk sınırları | 7 |
| A04 Insecure Design | Uygulama yalnız backend'le konuşur; AI ve veritabanı ağ içinde; hasta onayıyla paylaşım | 1, 4 |
| A05 Security Misconfiguration | Gizli bilgiler `.env`'de ve zorunlu; backend veritabanına en az yetkili `diamate_app` ile bağlanır; actuator yalnız `health`, bileşen detayı yok; `server_tokens off`; kapalı portlar | 8 |
| A06 Vulnerable Components | Spring Boot 4.1.3, Java 21; bağımlılık sürümleri sabit (`pom.xml`, `requirements.txt`); Dependabot güvenlik güncellemeleri ve haftalık OSV-Scanner/pip-audit taraması. İlk tarama (25 Kasım) Tomcat 11.0.24'te 4 kritik, Jackson 3.1.5'te 7 yüksek/orta açık ve `ai-service`'te `certifi 2026.7.22` buldu: Spring Boot 4.1.1 → 4.1.3 (Tomcat 11.0.27, Jackson 3.1.8) ve `certifi` 2026.11.20 ile kapatıldı | 11 |
| A07 Identification & Authentication Failures | Hesap kilidi ve IP başına giriş hız sınırı; aynı hata mesajı; pasif hesabın token'ı anında geçersiz | 2, 8 |
| A08 Software & Data Integrity | `audit_logs` trigger ile yalnız eklemeye açık; aynı JSON alanı iki kez → `400`; salt okunur jar, root olmayan kullanıcı; CI testleri çalıştırır | 6, 7, 8, 10 |
| A09 Logging & Monitoring Failures | Kapsamlı denetim kaydı; reddedilen erişimler de yazılır; sahte IP engellenir | 6 |
| A10 SSRF | Backend yalnız sabit `AI_SERVICE_BASE_URL`'e istek atar; kullanıcı adres veremez | 5 |

## 10. Doğrulama

| Kontrol | Sonuç (23 Kasım 2026) |
|---|---|
| Backend `mvn test` (birim, web, Testcontainers ile PostgreSQL) | **506/506** (24 Kasım; 12 veritabanı testi dahil, hiçbiri atlanmadı) |
| Flutter `flutter test` / `flutter analyze` | **167/167** (25 Kasım, `token_refresh_test.dart` dahil); analyze'da hata ve uyarı yok |
| Tam regresyon, demo verisiyle (25 Kasım; Database paketi araştırma verisi ve 12 demo hesabıyla + Flyway V2–V11, backend Spring Boot 4.1.3 ve `diamate_app` ile, gerçek AI servisi) | Postman koleksiyonunun tamamı **491 istek, 752/752 doğrulama**; `Database/tools/access_rules_test.sql` **58 kontrol**; `11_verify.sql` yapı ve demo kontrolleri temiz; `tools/api_fuzz_scan.py` **6409 bozuk istek, 0 bulgu** (hiç 5xx yok). Food-vision uçtan uca denenmedi (model dosyası yok) |
| Bağımlılık taraması (25 Kasım, `dependency-audit.yml`) | İlk çalıştırma: Tomcat 11.0.24 (4 kritik), Jackson 3.1.5 (7 yüksek/orta), `certifi` 2026.7.22. Spring Boot 4.1.3 ve `certifi` 2026.11.20 ile kapatıldı |
| Refresh/logout uçtan uca (24 Kasım; boş PostgreSQL 17 + Flyway V11 `migrate` servisiyle, backend `diamate_app` ile, Nginx HTTPS arkasında) | Postman "Sessions: refresh and logout": **14 istek, 20/20** — rotation, eski token'la yenilemede oturumun kapanması ve access token'ın hemen 401 alması, diğer cihazın etkilenmemesi, logout sonrası anında 401. Swagger `API_DOCS_ENABLED=true` iken 200 (OpenAPI 3.1, Bearer şeması), `false` iken `/swagger-ui.html`, `/v3/api-docs` 404. Bütün koleksiyon eski ve yeni kodla aynı boş veritabanında karşılaştırıldı: tek fark, `sid` claim'i için güncellenen OWASP A02 token testi (demo hesabı isteyen istekler boş veritabanında iki sürümde de aynı şekilde başarısız) |
| AI servisi `pytest` | **669/669** |
| Tam stack uçtan uca (Nginx + backend + AI + PostgreSQL, takım reposunun `main` compose dosyasıyla) | HTTP→HTTPS `308`; HSTS var; TLS 1.1 reddediliyor; kayıt/giriş/kayıt yazma; beş AI analizi `200`; gerçek ses kaydı `200`; 12 MB `413`; AI kapalı `503`; backend kapalı `503`; sahte `X-Forwarded-For` denetime geçmiyor; yalnız Nginx portu açık |
| Giriş hız sınırı (GP stack'i) | Kayıt + 4 yanlış giriş geçti; 5. yanlış giriş backend'in kilidi (`429`, `Retry-After: 900`); sonraki 7 istek Nginx `429` (`problem+json`, `Retry-After: 10`); 7 sn sonra kayıt ve giriş yeniden `200`; aynı anda 30 hızlı `/users/me` isteğinin hepsi `200` |
| CI | `backend-ci.yml`: `main`/`backend` push'larında ve PR'larda. `ai-service-ci.yml`: `ai` push'larında ve PR'larda |

Elle güvenlik testi listesi: `BACKEND_REVIEW.md` §12.8 ve Postman'deki "Security" klasörleri.

## 11. Açık kalanlar

| # | Konu | Risk | Öneri | Sahibi |
|---|---|---|---|---|
| S-A | ~~Backend veritabanına sahibi olan kullanıcıyla bağlanıyor~~ **Tam stack'te kapatıldı (23 Kasım):** backend `diamate_app` ile bağlanıyor, migration'ları ayrı `migrate` servisi uyguluyor (bölüm 8). Kalan: ortak Neon veritabanında backend hâlâ tek kullanıcıyla bağlanıyor | Neon'daki kullanıcı ele geçirilirse şema değiştirilebilir | Neon'da da `diamate_app`'e giriş izni verilsin; backend `.env`'de onunla, migration'lar sahip hesabıyla ayrı çalıştırılsın | Melih |
| ~~S-B~~ | ~~Giriş için IP başına hız sınırı yok~~ | — | **Kapatıldı (23 Kasım):** Nginx `limit_req`, bölüm 8 | Melih |
| ~~S-C~~ | ~~Refresh token ve sunucu tarafında logout yok (B-6)~~ | — | **Kapatıldı (24 Kasım):** 15 dk'lık access token + dönen, tekrar kullanımı yakalanan refresh token (V11 `auth_sessions`); `POST /auth/logout` access token'ı da hemen geçersiz kılar (bölüm 2). Mobil uygulama yenilemeyi kendisi yapar (`api_client.dart`) | Melih |
| S-D | Ortak geliştirme `JWT_SECRET`'i | Anahtarı bilen biri ortak veritabanındaki herhangi bir kullanıcı için token üretebilir | Üretimde anahtar yalnız sunucuda; sızıntı şüphesinde değiştirilir | Takım |
| S-E | Doktor kimliği doğrulanmıyor (onay 17 Kasım'da kaldırıldı) | Biri kendini doktor gibi tanıtıp hastadan davet isteyebilir | Uygulamada "doğrulanmamış hesap" uyarısı, ileride lisans doğrulaması veya admin onayı | Takım |
| S-F | AI servisinin ve `food-vision-service`'in kendi kimlik doğrulaması yok | Ağ dışına açılırsa herkes doğrudan çağırabilir | Ağ içinde kalsın (ikisi de compose'da yalnız `expose`); gerekirse backend ile servisler arasında paylaşılan bir anahtar | Ayşen + Ayşenur + Melih |
| S-M | `food-vision-service`: `/upload-image` fotoğrafları diske yazıyor (F-2); `/predict-food` `async def` içinde senkron model çalıştırıyor, aynı anda gelen istekler sırayla bekliyor (F-4); sürümler sabit değil (F-6) | Backend `/upload-image`'ı kullanmıyor, risk servise doğrudan erişilirse doğar. F-4 yükte gecikme yapar | `/upload-image` kaldırılsın ya da diske yazmasın; uç `def` olsun; `requirements.txt` sabitlensin | Ayşenur |
| S-G | AI servisi bozuk ses dosyasında `500` veriyor | Backend bunu `502` olarak iletiyor; kullanıcı neyin yanlış olduğunu öğrenemiyor | AI servisi geçersiz ses için `422` dönsün | Ayşen |
| S-H | AI CI `main` push'unda çalışmıyor | `main`'e doğrudan gelen bir AI değişikliği testsiz kalabilir | `ai-service-ci.yml` → `branches: [ai, main]` | Ayşen |
| S-I | Docker Desktop (macOS) istemcinin gerçek IP'sini göstermiyor | Yerel testte denetim kaydında `192.168.65.1` görünüyor | Linux sunucuda sorun yok; yalnız bilgi | — |
| ~~S-J~~ | ~~Bağımlılık taraması otomatik değil~~ **Kapatıldı (24–25 Kasım):** `.github/dependabot.yml` (Maven, pip ×2, pub, Docker, Compose, Actions; 25 Kasım'dan beri yalnızca güvenlik PR'ları, `open-pull-requests-limit: 0`) ve `.github/workflows/dependency-audit.yml` (OSV-Scanner: `pom.xml` + `pubspec.lock`; pip-audit: iki Python servisi; PR'da ve her pazartesi) | İlk çalıştırmanın bulguları kapatıldı (bölüm 9, A06). Kalan tek adım bir ayar: Settings → Code security → Dependabot alerts + security updates | Yeni açıklar Dependabot güvenlik PR'ı ve haftalık `dependency-audit.yml` bulgusu olarak gelir | Melih (ayar: repo sahibi) |
| S-K | Docker base image'ları etiketle sabit (`eclipse-temurin:21-jre`, `nginx:1.27-alpine`, `postgres:17`, `python:3.12-slim`) | Etiketin arkasındaki imaj değişebilir | Dependabot bu etiketleri izliyor; 25 Kasım'dan beri yalnızca güvenlik açığı olan imajlar için PR açıyor. Kalan: üretimde digest ile sabitlemek (`image@sha256:...`) | Takım |
| S-L | Güvenlik olayları için otomatik uyarı yok | `ACCOUNT_LOCKED` / `ACCESS_DENIED` artışı ancak denetim kayıtlarına bakılınca fark edilir | İzleme aracında eşik uyarısı | Sonra |
