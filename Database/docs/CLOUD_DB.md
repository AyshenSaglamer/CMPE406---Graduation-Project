# DiaMate bulut veritabanı (Neon) — ortak, 7/24

Melih'in Mac'i kapalıyken de ikiniz aynı veriyi görürsünüz. Tailscale/yerel Postgres artık gerekmez.

## Bir kez (Melih)
1. https://neon.com → hesap aç → proje `diamate` (bölge: Frankfurt/Avrupa). Postgres 17 veya üstü.
2. Connect → **Direct connection** (pooled DEĞİL) dizesini kopyala → `postgresql://user:pass@ep-xxx.eu-central-1.aws.neon.tech/DiaMateDB?sslmode=require`
3. Mac'te:
   ```
   cd "Graduate Project/Database/tools"
   export SRC_PASSWORD='<yerel şifre>'
   export DST_URL='<neon direct connection string>'
   MODE=lite ./migrate_to_cloud.sh
   ```
   Script boyutları yazar, dump alır, buluta yükler, kullanıcı sayısını (12) ve Flyway geçmişini gösterir.
4. Nilsu'yu Neon'a davet et: Project → Settings → Members (aynı veriye kendi kimliğiyle girer). Ya da ortak bir rol/şifre kullanın.

## Her ikiniz (DiaMate/.env)
```
POSTGRES_HOST=ep-xxx.eu-central-1.aws.neon.tech
POSTGRES_PORT=5432
POSTGRES_DB=DiaMateDB
POSTGRES_USER=DiaMateDB_owner (Neon sahip rolü)
POSTGRES_PASSWORD=<özel kanaldan>
POSTGRES_SSLMODE=require
JWT_SECRET=<ikinizde AYNI>
```
pgAdmin: aynı host/kullanıcı, SSL mode = require.
Neon boşta 5 dk sonra uyur; ilk bağlantı 1-2 sn gecikir, normaldir.

## Kurallar
- Şema değişikliği yalnızca Flyway: `DiaMate/src/main/resources/db/migration/V<n>__aciklama.sql`. Numara çakışmasın (PR'dan önce `git pull`).
- Elle ALTER/DROP yok, aksi halde kod ile DB ayrışır.
- Deneme yapmak istediğinde Neon **branch** aç (ücretsiz, ortak veriyi bozmaz), `POSTGRES_HOST`'u branch'e çevir.
- Yedek: Neon geçmiş geri yüklemesi var; ayrıca `pg_dump -Fc "$DST_URL" > diamate_$(date +%F).dump`.

## Durum (4 Eki 2026)
- Neon projesi `DiaMate` (Frankfurt, PG 17, Free) kuruldu; `MODE=lite` ile yüklendi: ~213 MB, 12 demo kullanıcı.
- `flyway_schema_history` yok: Spring Boot ilk açılışta mevcut şemayı V1 sayıp V2'yi (users: full_name -> ad/soyad, birth_date, gender) uygular.
- Bulutta hızlı sorgu: `Database/tools/cloud_psql.sh -c "..."` (bağlantı dizesini gizli kutuda sorar).

## Roller
Neon'da `diamate_app` ve `diamate_readonly` (NOLOGIN) rolleri olmalı; V2 migration `GRANT ... TO diamate_readonly` kullanır. `migrate_to_cloud.sh` bunları oluşturur; elle: `./cloud_psql.sh` ile `CREATE ROLE diamate_readonly NOLOGIN;`.

## Boyut notu
Ücretsiz katman ~0,5 GB. `MODE=lite` büyük research tablolarının (brfss_survey, food_images, activity, timeline) verisini atlar, yapıları durur. Eksik veri gerekirse yerel kopyadan (`install_mac.sh`) çalışılır ya da ücretli plana / VPS'e geçilir; `MODE=full` aynı script ile hepsini taşır.

## Nilsu için hızlı kurulum
1. Neon davetini kabul et; Melih bağlantı dizesini özel kanaldan gönderir (Pooled connection KAPALI, direct).
2. `Database/tools/set_env_from_neon.sh` çalıştır, dizeyi gizli kutuya yapıştır → `DiaMate/.env` otomatik yazılır (JWT_SECRET'ı ayrıca Melih'inkiyle aynı yap).
3. `cd DiaMate && mvn spring-boot:run` — V2 zaten uygulandı (4 Eki 2026), Flyway sadece sonraki migration'ları uygular.
