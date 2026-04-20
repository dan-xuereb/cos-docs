# Xuer Labs Workspace Docs

> Single entry-point to every COS / Xuer Labs repo's architecture, API,
> and diagrams. Built from ~29 sibling repos under `/home/btc/github/`
> via [mkdocs-monorepo-plugin](https://backstage.github.io/mkdocs-monorepo-plugin/).

The workspace is a quantitative-finance platform organized into 8 domains:
data ingestion (Forges), signal composition (Signal Stack), agent reasoning,
real-time presentation, on-chain analytics (Warehouse), network intelligence,
canonical schemas, and deployment/infrastructure. Use the left-nav to browse
by domain, or follow a link from the table below.

## Quick start

```bash
cd /home/btc/github/cos-docs
./scripts/build-all-api.sh --keep       # pre-render per-repo API pages in isolated venvs
mkdocs build --strict                    # aggregator build (zero warnings tolerated)
./scripts/build-all-api.sh --restore    # restore per-repo docs/api.md to declarative form

# Local preview (optional):
mkdocs serve                             # http://127.0.0.1:8000
```

See [Workspace Architecture](architecture.md) for the workspace-wide data-flow diagram.

## Repos by domain

### Forges — external data ingestion into Parquet / NFS

| Repo | Language | Purpose |
|------|----------|---------|
| [bis-forge](bis-forge/) | Python | BIS SDMX downloader |
| [bls-forge](bls-forge/) | Python | BLS downloader |
| [BTC-Forge](BTC-Forge/) | Python | Bitcoin OHLCV downloader (Coinbase/Kraken/Bitstamp) |
| [EDGAR-Forge](EDGAR-Forge/) | Python | SEC EDGAR filings downloader |
| [FRED-Forge](FRED-Forge/) | Python | FRED economic data downloader |
| [imf-forge](imf-forge/) | Python | IMF SDMX downloader |
| [ingest](ingest/) | Python | Shared ingestion primitives (reference connector) |
| [stooq-forge](stooq-forge/) | Python | Stooq market data downloader |

### Signal Stack — factor algebra, signal computation, composition, backtesting

| Repo | Language | Purpose |
|------|----------|---------|
| [COS-BTE](COS-BTE/) | Python | Backtesting engine (NautilusTrader) |
| [COS-CIE](COS-CIE/) | Python | Composite Indicator Engine — scoring + composition |
| [COS-MSE](COS-MSE/) | Python | Market Sentiment Engine — volatility regime research |
| [COS-SGL](COS-SGL/) | Python | Signal Generation Layer — multi-frequency signal mixing |
| [cos-signal-bridge](cos-signal-bridge/) | Python | SDL→SGL→BTE pipeline glue + IC feedback |
| [cos-signal-explorer](cos-signal-explorer/) | Python | Marimo research app for SDL factor authoring |

### Agent — LLM reasoning over workspace data

| Repo | Language | Purpose |
|------|----------|---------|
| [COS-Bitcoin-Protocol-Intelligence-Platform](COS-Bitcoin-Protocol-Intelligence-Platform/) | Python | BIP lifecycle tracking → investment intelligence |
| [COS-LangGraph](COS-LangGraph/) | Python | ReAct LLM agent (FastAPI, K8s NodePort 30091) |

### Presentation — live trading UI + institutional landing page

| Repo | Language | Purpose |
|------|----------|---------|
| [cos-webpage](cos-webpage/) | TS (Next.js) | Xuer Labs institutional landing page |
| [quant-dashboard](quant-dashboard/) | TS / React | Bloomberg-style trading dashboard |

### Warehouse — on-chain ETL + full-node deploy

| Repo | Language | Purpose |
|------|----------|---------|
| [coinbase_websocket_BTC_pricefeed](coinbase_websocket_BTC_pricefeed/) | Python | ZMQ price publisher (Coinbase WS → PUB:5555) |
| [COS-BTC-Node](COS-BTC-Node/) | Config / Docker | Bitcoin Core v27.2 full-node deploy |
| [COS-BTC-SQL-Warehouse](COS-BTC-SQL-Warehouse/) | Python | Bitcoin full-chain ETL → ClickHouse |

### Network — Bitcoin P2P peer topology

| Repo | Language | Purpose |
|------|----------|---------|
| [COS-BTC-Network-Crawler](COS-BTC-Network-Crawler/) | Python | Bitcoin peer topology (PostgreSQL + Neo4j) |
| [OrbWeaver](OrbWeaver/) | Python | Bitcoin network crawler |

### Schema — canonical Pydantic models + typed query layer

| Repo | Language | Purpose |
|------|----------|---------|
| [COS-Core](COS-Core/) | Python | Canonical Pydantic v2 schemas + forge adapters |
| [cos-data-access](cos-data-access/) | Python | Typed, cacheable query layer over catalog sources |

### Infrastructure — hardware, network, deploy specs

| Repo | Language | Purpose |
|------|----------|---------|
| [COS-Capability-Gated-Agent-Architecture](COS-Capability-Gated-Agent-Architecture/) | Spec | Zero-trust autonomous agent formal spec |
| [COS-Hardware](COS-Hardware/) | Docs | Server hardware specs and host inventory |
| [COS-Infra](COS-Infra/) | Docs / Config | Workspace deployment guides and K8s automation |
| [COS-Network](COS-Network/) | Docs / Config | Physical / VLAN / routing / firewall / services |

## Excluded from aggregation

- **COS-electrs** (Rust / Cargo-only — does not fit the MkDocs + Python pipeline)
- **capability-gated-agent-architecture** (lowercase duplicate; PascalCase version is canonical)
- **quant-dashboard-k8s-deployment** (mentioned in workspace CLAUDE.md but not present on disk as of 2026-04-19)
