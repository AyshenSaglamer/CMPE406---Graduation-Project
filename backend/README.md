# DiaMate Backend

DiaMate, diyabet öz yönetimi ve hasta izleme sistemidir. Bu proje, Flutter mobil uygulamasının (hasta, bakıcı, doktor) konuştuğu **REST API**'dir.

| | |
|---|---|
| Dil / çatı | Java 21, Spring Boot 4.1.1 (Spring MVC, Spring Data JPA / Hibernate 7, Spring Security + JWT, Bean Validation, Actuator) |
| Veritabanı | PostgreSQL 17, Docker (`localhost:5434`, veritabanı `diamate`) |
| Build | Maven |
| API | `/api/v1/...`, JSON; hatalar RFC 9457 `application/problem+json` |

## Gereksinimler

- JDK 21 (macOS: `brew install openjdk@21`)
- Docker Desktop
- `Database` (şema + veri paketi) ve `Dataset` (CSV verileri) klasörleri. **Şimdilik repoda değiller**, takım içinde ayrıca paylaşılır. Aşağıdaki `../Database` yolları, `Database` ve `Dataset` klasörlerini bu `backend` klasörünün yanına koyduğunuzu varsayar.

## 1. Ortam dosyası

```bash
cp .env.example .env
```

`.env` içinde `POSTGRES_PASSWORD` ve `JWT_SECRET` değerlerini doldurun (`JWT_SECRET` için: `openssl rand -base64 64`). `.env` Git'e **girmez**; hem Docker Compose hem Spring Boot bu dosyayı okur.

## 2. Veritabanını başlatma

```bash
docker compose up -d        # PostgreSQL 17, localhost:5434
docker compose ps           # STATUS: healthy olmalı
```

**İlk kez kuruluyorsa** (veritabanı boşsa) şemayı ve veriyi yükleyin (~1-2 dk):

```bash
set -a; . ./.env; set +a
cd ../Database
PGPORT=$POSTGRES_PORT PGUSER=$POSTGRES_USER PGDATABASE=$POSTGRES_DB PGPASSWORD=$POSTGRES_PASSWORD ./install_mac.sh
cd ../DiaMate
```

Sonuç: `public` şemasında 30 uygulama tablosu, `research` şemasında 14 veri seti tablosu, 12 demo hesap (bkz. `../Database/docs/DEMO_ACCOUNTS.md`).

> Backend **yalnızca** 5434'teki Docker veritabanına bağlanır. pgAdmin'deki 5433 ("PostgreSQL 18") kurulumu referanstır.
> `docker compose down -v` **tüm veriyi siler**; `docker compose stop` ya da `-v` olmadan `docker compose down` veriyi korur.

## 3. Backend'i çalıştırma

- **Eclipse:** `BackendApplication` → *Run As → Java Application*
- **Terminal:**
  ```bash
  export JAVA_HOME=$(/usr/libexec/java_home -v 21)   # ya da JDK 21'in yolu
  mvn spring-boot:run
  ```

Kontrol: `curl http://localhost:8080/api/v1/health` → `"status":"UP"`, `curl http://localhost:8080/actuator/health` → `"db":{"status":"UP"}`.

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
| POST | `/api/v1/auth/register` | herkese açık | `{fullName, email, password, role}` → 201. Rol: `PATIENT`, `CAREGIVER`, `CLINICIAN` (`ADMIN` kayıt olamaz) |
| POST | `/api/v1/auth/login` | herkese açık | `{email, password}` → `{accessToken, tokenType, expiresIn, user}` |

Diğer tüm adresler `Authorization: Bearer <accessToken>` ister (yoksa 401).

## Paket yapısı

```
com.diamate.backend
├── controller   HTTP katmanı (endpoint'ler)
├── service      iş mantığı
├── repository   veritabanı erişimi (Spring Data JPA)
├── entity       JPA entity'leri (veritabanı tabloları)
├── dto          API istek/cevap modelleri
├── security     BCrypt, JWT üretimi/doğrulaması, güvenlik kuralları
└── exception    uygulama hataları ve merkezi hata yönetimi
```

Veritabanı şeması ve eşleme notları: `../Database/docs/BACKEND_NOTES.md`, `../Database/docs/DATA_DICTIONARY.md`.
