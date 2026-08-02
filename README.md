# Running Events in Santarem

## English

This project collects, stores, and processes results from running events held in
Santarém, Brazil, published on [CronoSantarém](https://www.cronosantarem.com.br).
It is made up of two independent applications connected through Amazon S3:

- **[`web-scraper`](web-scraper/)** (Ruby) — scrapes the CronoSantarém results page,
  filters it down to running events (excluding cycling, swimming, trail, and
  triathlon), and parses each event's `.clax` result file to extract per-runner
  finishing data (position, bib number, name, category, finish time, pace, etc.).
  Results are stored as CSV files and optionally uploaded to S3 for downstream
  processing.
- **[`etl-pipeline`](etl-pipeline/)** (Python) — a medallion-architecture ETL
  pipeline (bronze → silver → gold) that reads the CSVs exported by the
  web-scraper (from S3 or a local fallback), cleans and deduplicates them,
  converts finish times/paces to numeric values, and builds business-ready
  marts such as per-event summaries and category podiums.

**Data flow:**

```
cronosantarem.com.br
        │  web-scraper (Ruby)
        ▼
data/events.csv, data/runners.csv  ──upload──▶  S3
                                                   │
                                                   ▼
                                     etl-pipeline (Python)
                                     bronze → silver → gold (parquet)
```

Each application has its own README with setup, usage, and architecture
details: [`web-scraper/README.md`](web-scraper/README.md) and
[`etl-pipeline/README.md`](etl-pipeline/README.md).

---

## Português

Este projeto coleta, armazena e processa resultados de corridas de rua
realizadas em Santarém, Pará, publicados no
[CronoSantarém](https://www.cronosantarem.com.br). Ele é composto por duas
aplicações independentes, conectadas através do Amazon S3:

- **[`web-scraper`](web-scraper/)** (Ruby) — busca a página de resultados do
  CronoSantarém, filtra apenas eventos de corrida de rua (excluindo ciclismo,
  natação, trail e triathlon) e faz o parsing do arquivo de resultados `.clax`
  de cada evento para extrair os dados de cada corredor (posição, número de
  peito, nome, categoria, tempo de prova, ritmo, etc.). Os resultados são
  armazenados em arquivos CSV e, opcionalmente, enviados ao S3 para
  processamento posterior.
- **[`etl-pipeline`](etl-pipeline/)** (Python) — um pipeline de ETL em
  arquitetura medallion (bronze → silver → gold) que lê os CSVs exportados
  pelo web-scraper (do S3 ou de um fallback local), limpa e remove
  duplicidades dos dados, converte tempos de prova/ritmo para valores
  numéricos e constrói marts prontos para análise, como resumos por evento e
  pódios por categoria.

**Fluxo de dados:**

```
cronosantarem.com.br
        │  web-scraper (Ruby)
        ▼
data/events.csv, data/runners.csv  ──upload──▶  S3
                                                   │
                                                   ▼
                                     etl-pipeline (Python)
                                     bronze → silver → gold (parquet)
```

Cada aplicação tem seu próprio README com detalhes de instalação, uso e
arquitetura: [`web-scraper/README.md`](web-scraper/README.md) e
[`etl-pipeline/README.md`](etl-pipeline/README.md).
