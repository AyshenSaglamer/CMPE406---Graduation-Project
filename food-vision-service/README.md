# food-vision-service

Yemek fotoğrafından yemeği tahmin eden FastAPI servisi (Ayşenur). ResNet50, Food-101 + 24 Türk yemeği, 125 sınıf,
test doğruluğu %77 (`reports/foodvision_test_results.json`).

Yalnız backend çağırır: uygulama → `POST /api/v1/ai/food` (backend) → `POST /predict-food` (bu servis). Fotoğraf
bellekte işlenir, diske yazılmaz. Cevap bir öneridir (`requires_user_confirmation: true`); hasta onaylamadan öğün
kaydedilmez.

| Uç | Ne yapar |
|---|---|
| `GET /api/health` | Model yüklüyse 200 (`classes: 125`), değilse 503 |
| `POST /predict-food` | multipart alan `file`: JPG/PNG/WEBP, ≤ 5 MB, ≤ 50 MP. En iyi 3 tahmin, güvene göre sıralı |

Hatalar: yanlış tür / boş / bozuk / çok büyük çözünürlük → 400, 5 MB üstü → 413, model yok → 503.

## Ağırlık dosyası (Git'te yok)

`best_resnet50_foodvision.pth` (95 MB) `models/` klasörüne konmalı. Yoksa servis açılmaz, backend `/ai/food` için 503
döner, uygulamanın geri kalanı çalışır.

## Yerelde çalıştırma ve test

```bash
pip install -r requirements-dev.txt
python -m pytest -q                       # gerçek ağırlık gerekmez (sahte model)
uvicorn app:app --port 8001
curl -F "file=@yemek.jpg;type=image/jpeg" localhost:8001/predict-food
```

## Demo kontrol listesi

Demo makinesinde, bir gün önce:

1. [ ] `main` güncel: `git pull`
2. [ ] `food-vision-service/models/best_resnet50_foodvision.pth` yerinde (Drive'dan)
3. [ ] Kök dizinde `.env`: `POSTGRES_PASSWORD`, `APP_DB_PASSWORD`, `JWT_SECRET` (`.env.example`'dan)
4. [ ] `docker compose up -d --build` → `docker compose ps`: `food-vision` **healthy**
5. [ ] Uygulamada hasta olarak giriş → öğün → fotoğraf: tahmin + karbonhidrat görünüyor
6. [ ] Yanlış tahmini düzeltip kaydet → öğün `AI_PHOTO` olarak listede

Demoda kullanılacak, önceden denenmiş fotoğraflar (yüksek güven): hamburger, pizza, spaghetti bolognese.
Bir de belirsiz bir fotoğraf gösterilebilir: düşük güven uyarısı ve kullanıcı onayı burada anlam kazanır.

Sorun çıkarsa: `docker compose logs food-vision` → `ResNet50 loaded successfully! Classes: 125` satırı yoksa ağırlık
dosyası eksik ya da bozuk.
