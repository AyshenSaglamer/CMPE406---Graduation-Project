# food-vision-service

Yemek fotoğrafından yemeği (ve tabakta birden fazla yemek varsa her birini) tahmin eden FastAPI servisi (Ayşenur).

| Model | Ne yapar |
|---|---|
| ResNet50 (`models/best_resnet50_foodvision.pth`) | Food-101 + 24 Türk yemeği, 125 sınıf, test doğruluğu %77 (`reports/foodvision_test_results.json`) |
| YOLO (`yolo26n.pt`, COCO) | Tabaktaki yemek bölgelerini bulur (kase, pizza, sandviç, kek, meyve, ...). Her bölge kırpılır ve aynı ResNet50 ile sınıflandırılır |

Yalnız backend çağırır: uygulama → `POST /api/v1/ai/food` (backend, besin değerleri ve porsiyonlar `food_catalog`'dan)
→ `POST /predict-food` (bu servis). Fotoğraf bellekte işlenir, diske yazılmaz. Cevap bir öneridir
(`requires_user_confirmation: true`); hasta onaylamadan öğün kaydedilmez.

## API

| Uç | Ne yapar |
|---|---|
| `GET /api/health` | Model yüklüyse 200 (`classes: 125`, `multi_food: true/false`), değilse 503 |
| `POST /predict-food` | multipart alan `file`: JPG/PNG/WEBP, ≤ 5 MB, ≤ 50 MP |

`/predict-food` cevabı:

```json
{
  "success": true, "model": "ResNet50",
  "predicted_food": "pizza", "confidence": 0.5207,
  "top_predictions": [{"food": "pizza", "confidence": 0.5207}, ...],
  "items": [
    {"box": [0.0504, 0.1754, 0.2733, 0.8135], "detector_label": "sandwich", "detector_confidence": 0.88,
     "top_predictions": [{"food": "hamburger", "confidence": 0.9999}, ...]},
    {"box": [0.3593, 0.1637, 0.6451, 0.7603], "detector_label": "pizza", "detector_confidence": 0.91,
     "top_predictions": [{"food": "pizza", "confidence": 0.9954}, ...]}
  ],
  "multiple_foods": true,
  "requires_user_confirmation": true
}
```

- `top_predictions`: bütün fotoğraf tek yemek olarak (en iyi 3).
- `items`: her yemek bölgesi ayrı ayrı (en fazla 5). `box` fotoğrafın genişlik/yüksekliğine göre 0..1.
  Bölge seçimi: yalnız yemek sınıfları (bardak ve masa hariç), güven ≥ 0.35, alan ≥ %3, örtüşen (IoU > 0.5) bölgelerden
  en güvenlisi.
- `multiple_foods`: iki ya da daha fazla bölge bulunduysa `true`. Uygulama o zaman yemekleri tek tek gösterir.

Örnek (üç yemekli test tabağı): bütün fotoğraf "pizza %52" derken bölgeler hamburger %99.99, pizza %99.5 ve
spaghetti bolognese %71 buldu.

Hatalar: yanlış tür / boş / bozuk / çok büyük çözünürlük → 400, 5 MB üstü → 413, model yok → 503.
YOLO yüklenemezse ya da hata verirse servis çalışmaya devam eder, `items` boş döner.

## Ayarlar (ortam değişkenleri)

| Değişken | Varsayılan | |
|---|---|---|
| `FOOD_VISION_MODEL_DIR` | `models/` | `food_classes.json` ve `.pth` burada |
| `FOOD_VISION_DETECTOR` | `models/yolo26n.pt` (Docker'da `/opt/yolo/yolo26n.pt`) | YOLO ağırlıkları; yoksa çoklu tanıma kapalı |
| `FOOD_VISION_MULTI_FOOD` | `true` | `false` ile çoklu tanıma kapatılır |

## Ağırlık dosyası (Git'te yok)

`best_resnet50_foodvision.pth` (95 MB) `models/` klasörüne konmalı. Yoksa servis açılmaz, backend `/ai/food` için 503
döner, uygulamanın geri kalanı çalışır. YOLO ağırlıkları Docker imajı derlenirken indirilir.

## Yerelde çalıştırma ve test

```bash
pip install -r requirements-dev.txt
python -m pytest -q                       # gerçek ağırlık gerekmez (sahte model ve sahte YOLO)
uvicorn app:app --port 8001
curl -F "file=@yemek.jpg;type=image/jpeg" localhost:8001/predict-food
```

Docker Compose'da servis `food-vision` adıyla, yalnız iç ağda (`expose: 8001`) çalışır:
`docker compose up -d --build`, sonra `docker compose ps` ile `food-vision`'ın **healthy** olduğu görülür.
