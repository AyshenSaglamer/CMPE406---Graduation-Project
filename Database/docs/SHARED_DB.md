# DiaMate ortak geliştirme veritabanı

**Güncel kurulum: bulut (Neon, Frankfurt, PostgreSQL 17) — bkz. [CLOUD_DB.md](CLOUD_DB.md).**
Melih'in Mac'inin açık olmasına gerek yok; ikiniz de aynı veritabanına her zaman bağlanırsınız.

Eski Tailscale/yerel kurulum artık kullanılmıyor (dokümanı yalnızca Melih'in çalışma reposunda).

Kısa kural: şema değişikliği yalnızca `DiaMate/src/main/resources/db/migration/V<n>__aciklama.sql` ile yapılır;
şifre ve `JWT_SECRET` commit'lenmez, özel kanaldan paylaşılır.
