# Running Events in Santarem

## English

This project collects, stores, and processes results from running events held in
Santarém, Brazil, published on [CronoSantarém](https://www.cronosantarem.com.br).

**The problem:** each event's results page offers PDF and XLS download
buttons, but neither works as advertised. The PDF button doesn't produce a
file at all, and the XLS button downloads a file with an `.xls` extension
whose content is actually raw HTML markup (`<table>`, `<td>`, inline styles,
HTML entities) rather than real spreadsheet data — unusable for any kind of
analysis without extensive manual cleanup. That gap is what motivated this
project: instead of depending on those broken exports, `web-scraper` reads
the results straight from the event's underlying `.clax` data source and
turns them into clean, structured CSV files fit for downstream processing.

The project is made up of two independent applications connected through Amazon S3:

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
- **[`orchestration`](orchestration/)** (Python, Prefect) — chains the two
  apps above into one end-to-end run (scrape → upload → bronze → silver →
  gold) with retries, logging, and an optional monthly schedule.

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

`orchestration/` sequences the two steps above end to end; see its README for
running once or on a schedule.

Each application has its own README with setup, usage, and architecture
details: [`web-scraper/README.md`](web-scraper/README.md),
[`etl-pipeline/README.md`](etl-pipeline/README.md), and
[`orchestration/README.md`](orchestration/README.md).

---

## Português

Este projeto coleta, armazena e processa resultados de corridas de rua
realizadas em Santarém, Pará, publicados no
[CronoSantarém](https://www.cronosantarem.com.br).

**O problema:** a página de resultados de cada evento oferece botões de
download em PDF e XLS, mas nenhum dos dois funciona como deveria. O botão de
PDF simplesmente não gera nenhum arquivo, e o botão de XLS baixa um arquivo
com extensão `.xls` cujo conteúdo, na verdade, é HTML puro (`<table>`,
`<td>`, estilos inline, entidades HTML) em vez de dados reais de planilha —
inutilizável para qualquer tipo de análise sem uma limpeza manual extensa.
Essa lacuna foi o que motivou o projeto: em vez de depender dessas
exportações quebradas, o `web-scraper` lê os resultados diretamente da fonte
de dados `.clax` de cada evento e os transforma em arquivos CSV limpos e
estruturados, prontos para processamento posterior.

O projeto é composto por duas aplicações independentes, conectadas através do Amazon S3:

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
- **[`orchestration`](orchestration/)** (Python, Prefect) — encadeia as duas
  aplicações acima em uma execução ponta a ponta (scrape → upload → bronze →
  silver → gold), com retries, logging e agendamento mensal opcional.

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

`orchestration/` encadeia as duas etapas acima ponta a ponta; veja o README
dessa pasta para rodar uma vez ou em agendamento.

Cada aplicação tem seu próprio README com detalhes de instalação, uso e
arquitetura: [`web-scraper/README.md`](web-scraper/README.md),
[`etl-pipeline/README.md`](etl-pipeline/README.md) e
[`orchestration/README.md`](orchestration/README.md).
