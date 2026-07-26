# Trino First Project

Пет-проект для практического знакомства с [Trino](https://trino.io/) как query-движком поверх лейкхаус-архитектуры: Hive Metastore + MinIO (S3-совместимое хранилище) + Postres (backend для метастора), всё поднимается локально через Docker Compose.

## Архитектура

```
                    ┌──────────────────┐
                    │  Trino Coordinator│
                    │   (localhost:8080)│
                    └────────┬──────────┘
                             │ Thrift (9083)
                    ┌────────▼──────────┐
                    │  Hive Metastore   │
                    │ (starburstdata/   │
                    │     hive)         │
                    └────────┬──────────┘
                             │ JDBC (3306)
              ┌──────────────┼──────────────┐
              │                             │
     ┌────────▼────────┐          ┌─────────▼────────┐
     │     Postres      │          │       MinIO       │
     │ (metastore_db)   │          │  (S3-хранилище)   │
     └──────────────────┘          └────────────────────┘
```

- **Trino** — распределённый SQL-движок, единая точка входа для запросов.
- **Hive Metastore** — хранит метаданные (схемы, таблицы, партиции) и отдаёт их Trino по Thrift-протоколу.
- **Postres** — реляционное хранилище для самого метастора (таблицы `DBS`, `TBLS`, `SDS` и т.д.).
- **MinIO** — S3-совместимое объектное хранилище, куда физически пишутся данные таблиц (Parquet).

## Стек

| Компонент       | Образ                          | Порт(ы)      |
|-----------------|--------------------------------|--------------|
| Trino Coordinator | `trinodb/trino:latest`       | 8080         |
| Hive Metastore  | `starburstdata/hive:3.1.3-e.4` | 9083         |
| Postres         | `Postres:latest`               | 3306         |
| MinIO           | `minio/minio:latest`           | 9000, 9001   |

> **Почему `starburstdata/hive`, а не `bitsondatadev/hive-metastore`?**
> Изначально использовался `bitsondatadev/hive-metastore`, но на Apple Silicon (arm64) он собран только под `linux/amd64` и запускается через эмуляцию — это приводило к нестабильности и падениям при инициализации схемы. `starburstdata/hive` имеет нативную arm64-сборку и настраивается через переменные окружения, а не XML-конфиг.

## Быстрый старт

### 1. Требования

- Docker Desktop (с поддержкой Docker Compose v2)
- Свободные порты: `3306`, `8080`, `9000`, `9001`, `9083`

### 2. Запуск

```bash
docker compose up -d
```

Дай сервисам подняться (метастору может понадобиться до 30–60 секунд на первичную инициализацию схемы в Postres):

```bash
docker compose logs -f hive-metastore
```

Дождись строки о старте Metastore Server без ошибок.

Проверить состояние всех контейнеров:

```bash
docker compose ps
```

Ожидаемый результат — все четыре сервиса в статусе `Up`.

### 3. Создание bucket в MinIO

Открой MinIO Console: [http://localhost:9001](http://localhost:9001)
(логин/пароль — см. `docker-compose.yaml`, переменные `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY`)

Создай bucket, например `warehouse` — именно туда Trino будет писать данные таблиц.

### 4. Подключение к Trino

**Web UI:**
[http://localhost:8080](http://localhost:8080) (аутентификация отключена, логин — любое имя)

**CLI (через контейнер):**
```bash
docker exec -it trino-coordinator trino
```

**CLI (локально, через Homebrew):**
```bash
brew install trino
trino --server http://localhost:8080
```

### 5. Первый запрос

```sql
SHOW CATALOGS;

CREATE SCHEMA minio.raw
WITH (location = 's3://warehouse/raw/');

USE minio.raw;

CREATE TABLE test_table (
    id BIGINT,
    name VARCHAR
)
WITH (
    format = 'PARQUET'
);

INSERT INTO test_table VALUES (1, 'hello'), (2, 'world');

SELECT * FROM test_table;
```

Если запрос отработал — вся цепочка Trino → Hive Metastore → Postres → MinIO рабочая.

## Структура репозитория

```
.
├── conf/                # Конфигурационные файлы (metastore-site.xml и т.п.)
├── etc/                 # Конфигурация Trino (node.properties, jvm.config, config.properties, catalog/)
├── sql/                 # SQL-скрипты для проверки/наполнения данных
├── trino-catalog/       # Конфигурации Trino-каталогов
├── check_schema.py      # Python-скрипт для проверки состояния схемы/метастора
├── requirements.txt     # Python-зависимости для check_schema.py
└── docker-compose.yaml  # Оркестрация всех сервисов
```

## Полезные команды

```bash
# Полная пересборка с нуля (удаляет все volumes — данные Postres и MinIO)
docker compose down -v
docker compose up -d

# Логи конкретного сервиса
docker compose logs -f hive-metastore

# Список каталогов Trino
docker exec -it trino-coordinator trino --execute "SHOW CATALOGS"
```

## Известные грабли

- **`UnknownHostException: hive-metastore`** — метастор ещё не поднялся или не в той сети. Проверь `docker compose ps` и подожди инициализацию.
- **`Too many connections` в логах метастора** — обычно следствие зацикленных рестартов после сбойной инициализации схемы. Лечится через `docker compose down -v` и чистый старт.
- **Ошибки конфигурации `hive.s3.*` / `fs.native-s3.enabled`** — актуальная версия Trino использует `fs.s3.enabled` и `s3.*` вместо устаревших `hive.s3.*` параметров. См. `etc/catalog/*.properties`.
- **Platform mismatch warning на arm64** — решается использованием `starburstdata/hive` вместо `bitsondatadev/hive-metastore`.

## Roadmap

- [ ] Подключение dbt поверх Trino
- [ ] Добавление ClickHouse как отдельного каталога
- [ ] Data Vault 2.0 слой поверх Hive/Iceberg таблиц
- [ ] CI-проверка поднятия стека (health-check пайплайн)

## Лицензия

Пет-проект для обучения, лицензия не определена.