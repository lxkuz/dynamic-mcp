# Переменные окружения и деплой

> Шаблон: **[env.example](env.example)** · деплой: **[docs/DEPLOY.md](docs/DEPLOY.md)**

## Локально

```bash
cp env.example .env
docker-compose build parser_sandbox web sidekiq
docker-compose up -d
```

## Демо-стенд

https://bookworm.breget.tech

```bash
git push origin main
./deploy.sh
```

HTTPS (один раз): `./script/setup-nginx-remote.sh`
