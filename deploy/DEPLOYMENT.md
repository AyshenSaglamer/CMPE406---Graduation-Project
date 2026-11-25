# DiaMate — Production Kurulumu

Bu rehber DiaMate'i gerçek bir alan adıyla, internete açık bir Linux sunucuya kurar: Nginx (HTTPS, Let's Encrypt sertifikası), Spring Boot backend, PostgreSQL ve iki AI servisi, hepsi Docker Compose ile. Geliştirme kurulumu (yerel sertifika, `localhost:8443`) için repo kökündeki `docker-compose.yml` başındaki açıklamaya ve `backend/docs/DEVELOPER_GUIDE.md`'ye bakın.

Sorumlular: **Melih** (backend, güvenlik, compose), **Ayşen** (sunucu, AI servisi), **Ayşenur** (food-vision modeli).

```text
İnternet ──443──► Nginx (TLS, HSTS, giriş hız sınırı) ──► backend:8080 ──► database:5432
           ──80───► yalnız 308 → HTTPS ve Let's Encrypt doğrulaması      ├─► ai-service:8000
                                                                        └─► food-vision:8001
certbot: sertifikayı günde iki kez kontrol eder, 30 günden az kaldıysa yeniler
```

Dışarıya yalnız 80 ve 443 açılır. Veritabanı ve AI servisleri yalnız Docker ağındadır.

## 1. Gerekenler

| | En az | Not |
|---|---|---|
| Sunucu | Ubuntu 24.04 LTS, 2 vCPU, **8 GB RAM**, 40 GB disk | Whisper (ses) ve ResNet50 (fotoğraf) bellekte ~3 GB tutar. 4 GB'ta `WHISPER_MODEL_SIZE=tiny` ile çalışır |
| Alan adı | Bir A kaydı, örn. `api.diamate.example` → sunucunun IP'si | Let's Encrypt yalnız alan adına sertifika verir, IP'ye vermez |
| Yazılım | Docker Engine 27+ ve Compose eklentisi (`docker compose version` ≥ 2.24) | `!override` etiketi için 2.24 gerekir |
| Model dosyası | `food-vision-service/models/best_resnet50_foodvision.pth` | Git'te yok, Ayşenur'dan alınır. Yoksa yalnız `/ai/food` 503 verir |

## 2. Sunucuyu hazırlama

```bash
# Docker (resmî kurulum betiği)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER && newgrp docker

# Güvenlik duvarı: yalnız SSH, HTTP, HTTPS
sudo ufw allow OpenSSH && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp && sudo ufw enable

# Otomatik güvenlik güncellemeleri
sudo apt-get install -y unattended-upgrades && sudo dpkg-reconfigure -plow unattended-upgrades
```

SSH'ta şifreyle girişi kapatın (`/etc/ssh/sshd_config`: `PasswordAuthentication no`), yalnız anahtarla girilsin.

## 3. Kodu ve ayarları yerleştirme

```bash
sudo mkdir -p /opt/diamate && sudo chown $USER /opt/diamate
git clone https://github.com/AyshenSaglamer/CMPE406---Graduation-Project.git /opt/diamate
cd /opt/diamate
cp .env.example .env && chmod 600 .env
```

`.env` içinde **production değerleri** (geliştirme değerleri asla kullanılmaz):

| Değişken | Değer |
|---|---|
| `DOMAIN` | `api.diamate.example` |
| `LETSENCRYPT_EMAIL` | Sertifika süresi uyarılarının gideceği takım adresi |
| `POSTGRES_PASSWORD` | `openssl rand -hex 24` |
| `APP_DB_PASSWORD` | `openssl rand -hex 24` (öncekinden farklı) |
| `JWT_SECRET` | `openssl rand -base64 64` — **yalnız bu sunucuda**; geliştirme anahtarı değil (SECURITY.md S-D) |
| `JWT_EXPIRATION` | `15m` |
| `JWT_REFRESH_EXPIRATION` | `30d` |
| `API_DOCS_ENABLED` | `false` (prod compose bunu zaten zorlar) |
| `AUTH_RATE_LIMIT`, `AUTH_RATE_BURST` | `10r/m`, `5` |
| `WHISPER_MODEL_SIZE` | `base` (4 GB RAM'de `tiny`) |

`.env` ve `deploy/backups/` Git'e girmez. Şifreleri takımın şifre yöneticisinde saklayın, sohbet uygulamalarına yazmayın.

## 4. İlk sertifika ve ilk açılış

DNS kaydının sunucuyu gösterdiğini kontrol edin (`dig +short api.diamate.example`), sonra:

```bash
STAGING=1 ./deploy/init-letsencrypt.sh   # önce Let's Encrypt'in test CA'sıyla dene (hız sınırına takılmaz)
./deploy/init-letsencrypt.sh             # sonra gerçek sertifika
```

Betik sırayla: geçici bir sertifika koyar → Nginx'i ve arkasındaki stack'i açar (ilk seferde imajlar derlenir, 10–15 dk) → Let's Encrypt'ten gerçek sertifikayı alır → Nginx'i yeniden yükler. Sonraki yenilemeleri `certbot` servisi kendisi yapar, Nginx 6 saatte bir yeniden yüklenip yeni sertifikayı alır.

Bundan sonra stack'i her zaman iki dosyayla yönetin:

```bash
alias dc='docker compose -f docker-compose.yml -f docker-compose.prod.yml'
dc up -d --build      # aç / güncelle
dc ps                 # durum
dc logs -f backend    # log
```

## 5. Doğrulama

```bash
curl -sI http://api.diamate.example/api/v1/health | head -1          # 308 (HTTPS'e yönlendirme)
curl -s https://api.diamate.example/api/v1/health                   # {"status":"UP",...}
curl -s https://api.diamate.example/actuator/health                 # {"status":"UP",...} (veritabanı dahil)
curl -sI https://api.diamate.example/swagger-ui.html | head -1       # 404 (Swagger production'da kapalı)
```

- **TLS notu:** https://www.ssllabs.com/ssltest/ ile alan adını test edin; beklenen **A** (TLS 1.2/1.3, HSTS).
- **Mobil uygulama:** `ApiConfig.baseUrl` → `https://api.diamate.example`. Gerçek sertifika olduğu için telefona CA yüklemek gerekmez.
- **Uçtan uca:** Postman koleksiyonunun "Auth" ve "Sessions: refresh and logout" klasörleri `baseUrl=https://api.diamate.example/api/v1` ile çalıştırılabilir (test hesapları açar; gerçek kullanıcılar varken çalıştırmayın).

## 6. Yedekleme

```bash
./deploy/backup-db.sh                      # deploy/backups/diamate-<tarih>.sql.gz, son 14 tanesi tutulur
crontab -e                                 # her gece 03:00:
0 3 * * * /opt/diamate/deploy/backup-db.sh >> /var/log/diamate-backup.log 2>&1
```

Yedekler sağlık verisi içerir: dosyalar `600`, klasör `700`. Sunucu dışına (şifreli) kopyalanmazsa sunucu kaybında yedek de kaybolur; en azından haftada bir `scp` ile takımın güvenli depolamasına alın.

**Yedekten geri dönme:**

```bash
dc stop backend
gunzip -c deploy/backups/diamate-<tarih>.sql.gz | dc exec -T database sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
dc start backend
```

Geri dönüşü en az bir kez boş bir test sunucusunda deneyin; denenmemiş yedek, yedek sayılmaz.

## 7. Güncelleme

```bash
cd /opt/diamate
./deploy/backup-db.sh                       # önce yedek
git pull --ff-only
dc up -d --build                            # migrate servisi yeni Flyway sürümlerini uygular, sonra backend açılır
dc logs --tail=50 migrate backend
```

Yeni migration'lar `migrate` servisinde sahip hesabıyla çalışır; backend yalnız `diamate_app` hesabıyla bağlanır (SECURITY.md bölüm 8). Bir migration başarısız olursa backend açılmaz ve eski sürüm de kapanmış olur: yedekten dönüp (bölüm 6) önceki commit'e geri geçin (`git checkout <önceki>` + `dc up -d --build`).

## 8. Günlük işletme

| Ne | Nasıl |
|---|---|
| Sertifika ne zaman bitiyor | `dc run --rm --entrypoint certbot certbot certificates` |
| Sertifikayı hemen yenile | `dc run --rm --entrypoint certbot certbot renew --webroot -w /var/www/certbot --force-renewal && dc exec nginx nginx -s reload` |
| Şüpheli girişler | Denetim kaydı: `GET /api/v1/admin/audit-logs?action=LOGIN_FAILED` (ADMIN token'ı ile) ya da `REFRESH_TOKEN_REUSED`, `ACCESS_DENIED` |
| Bir hesabı hemen durdur | `PATCH /api/v1/admin/users/{id}/status` `{"active": false}` — hesabın bütün oturumları anında 401 alır |
| `JWT_SECRET` sızdı | `.env`'de yeni anahtar → `dc up -d backend`. Bütün access token'lar anında geçersiz olur; uygulamalar refresh token'la yeni token alır (refresh token'lar JWT değildir, anahtardan etkilenmez). Herkesi çıkarmak için: `dc exec database psql -U diamate -d diamate -c "update auth_sessions set revoked_at = now(), revoke_reason = 'LOGOUT' where revoked_at is null"` |
| Disk doluyor | `docker system df`; eski imajlar: `docker image prune -f` |

## 9. Production'a çıkmadan önce kontrol listesi

- [ ] `.env`'de bütün şifreler ve `JWT_SECRET` yeni üretildi, geliştirme değerleriyle aynı değil
- [ ] `STAGING=1` ile denendi, sonra gerçek sertifika alındı; SSL Labs notu A
- [ ] `http://` → `308`, `https://.../api/v1/health` → `UP`, `/swagger-ui.html` kapalı
- [ ] Yalnız 22, 80, 443 açık (`sudo ufw status`), `dc ps`'de yalnız nginx'in portu yayınlanmış
- [ ] Gece yedeği cron'da, bir geri dönüş denendi
- [ ] Demo hesapları (`Database/docs/DEMO_ACCOUNTS.md`) production veritabanında **yok** (demo seed yüklenmez; kontrol: `dc exec database psql -U diamate -d diamate -c "select count(*) from users where email like '%@diamate.example'"` → 0)
- [ ] Mobil uygulama production adresine bakıyor ve giriş → kayıt ekleme → çıkış akışı denendi
- [ ] GitHub'da Dependabot alerts ve security updates açık (Settings → Code security)
