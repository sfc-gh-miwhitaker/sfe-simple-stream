![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--01--01-orange)

# Simple Stream

> ⚠️ **DEMONSTRATION PROJECT - EXPIRES: 2026-01-01**  
> This demo uses Snowflake features current as of December 2025.  
> After expiration, this repository will be archived and made private.

**Author:** SE Community  
**Purpose:** Reference implementation for high-speed data ingestion with Snowpipe Streaming  
**Created:** 2025-12-02 | **Expires:** 2026-01-01 (30 days) | **Status:** ACTIVE

---

High-speed data ingestion with Snowpipe Streaming, deployed from Git in one command.

---

## 👋 First Time Here?

### Two Paths: Choose Your Use Case

---

#### Path A: Internal Testing (I want to test the full pipeline myself)

**Time:** ~3 minutes total (fully automated)

**Step 1: Deploy Snowflake Infrastructure (1 minute)**
1. Open Snowsight
2. Copy entire contents of [`deploy_all.sql`](deploy_all.sql)
3. Paste into worksheet → Click **"Run All"**
4. Copy your account identifier from final result pane

**Step 2: Run Automated Test (2 minutes)**
```bash
./tools/02_setup_and_test.sh
# Paste account identifier when prompted
```

**Script handles everything:** RSA keys → SQL auth → Python setup → Event sending

**Result:** 10 test events flow through entire pipeline (raw → staging → analytics)

**→ Next:** [`docs/03-TESTING.md`](docs/03-TESTING.md) for verification queries

---

#### Path B: External Data Provider Handoff (I need to onboard a vendor)

**Time:** ~1 minute (send one document)

**Step 1: Deploy Snowflake Infrastructure** (same as Path A above)

**Step 2: Generate Credentials for Vendor**
```bash
# Generate RSA key pair for vendor
mkdir -p vendor_credentials
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out vendor_credentials/vendor_key.p8 -nocrypt
openssl rsa -in vendor_credentials/vendor_key.p8 -pubout -outform PEM > vendor_credentials/vendor_key.pub

# Register vendor's public key in Snowflake (see docs/06-DATA-PROVIDER-QUICKSTART.md)
```

**Step 3: Send Vendor Documentation**
- **Quickstart:** [`docs/06-DATA-PROVIDER-QUICKSTART.md`](docs/06-DATA-PROVIDER-QUICKSTART.md) (10-minute integration guide)
- **Credentials:** Account ID, username (`SFE_INGEST_USER`), private key file
- **Result:** Vendor can stream events in 10 minutes using official Snowflake SDK

**→ Next:** [`docs/06-DATA-PROVIDER-QUICKSTART.md`](docs/06-DATA-PROVIDER-QUICKSTART.md) - Send this to your vendor

---

**Total setup time:** 
- **Internal testing:** ~3 minutes (automated)
- **Vendor handoff:** ~1 minute (generate credentials) + 10 minutes (vendor integration)

**For detailed guides:** See [`docs/`](docs/) directory

---

## What You Get

A complete streaming pipeline with:
- **Snowpipe Streaming SDK** for high-throughput ingestion (Rust-based core, official Snowflake library)
- **Automated CDC tasks** (deduplication, enrichment) running every minute
- **Dimensional model** (users, zones, facts) with Type 2 SCDs
- **Real-time monitoring views** (7 built-in SQL views)
- **📊 Interactive Streamlit dashboard** (native Snowflake, 6 monitoring pages, auto-refresh)
- **Git-based deployment** (no manual file uploads)
- **Simplified authentication** (SDK handles all JWT complexity automatically)

---

## Architecture

**Deployment Method:** Git-integrated (one command pulls scripts from GitHub)

**Data Flow:**
```
Snowpipe Streaming SDK → RAW Table → Stream → Tasks → Staging → Analytics
```

**Detailed Diagrams:**
- [`diagrams/data-model.md`](diagrams/data-model.md) - Database schema (ERD)
- [`diagrams/data-flow.md`](diagrams/data-flow.md) - Transformation pipeline
- [`diagrams/network-flow.md`](diagrams/network-flow.md) - Network architecture
- [`diagrams/auth-flow.md`](diagrams/auth-flow.md) - Authentication flow

---

## Key Features

### 1. Snowpipe Streaming REST API
- High-speed ingestion (millions of events/second)
- JSON transformation in pipe (server-side processing)
- Low latency (< 1 minute to queryable)

### 2. Git-Based Deployment
- `EXECUTE IMMEDIATE FROM @repo/...` pattern
- Version controlled pipeline
- No manual file uploads
- Always deploys latest from GitHub

### 3. CDC with Streams & Tasks
- Automatic change tracking via streams
- Incremental processing (only new data)
- Task DAG (dependent execution order)

### 4. Dimensional Modeling
- Type 2 Slowly Changing Dimensions
- Clustered fact table for performance
- Pre-seeded sample data for testing

### 5. Built-in Monitoring
- **📊 Interactive Streamlit Dashboard** (native Snowflake, 6 pages)
  - Real-time pipeline health indicators
  - Ingestion metrics with interactive charts
  - Cost tracking and optimization insights
  - Task execution monitoring
  - Query performance analytics
- **7 SQL Monitoring Views** (programmatic access)
  - Ingestion metrics (rate, volume, trends)
  - Cost tracking and estimates
  - Data quality metrics

---

## Quick Deploy (45 seconds)

**Step 1: Deploy Pipeline**

Copy/paste into Snowsight worksheet:
```sql
@deploy_all.sql
```

**Result:** Complete pipeline deployed in ~45 seconds

**Step 2: Validate**

```sql
(validation now automatic in deploy_all.sql)
```

**Step 3: Configure Authentication**

```sql
@sql/01_setup/01_configure_auth.sql
```

**Step 4: Send Test Events**

```bash
cd examples
../tools/02_setup_and_test.sh  # Master automation script (keys, SQL, Python, events)
./send_events.sh              # Send test data
```

**Full instructions:** See [`docs/03-TESTING.md`](docs/03-TESTING.md)

---

## What It Creates

### Database Structure

| Schema | Tables | Purpose |
|--------|--------|---------|
| `RAW_INGESTION` | RAW_BADGE_EVENTS | Landing table (append-only) |
| | sfe_badge_events_stream | CDC stream |
| | sfe_badge_events_pipe | Streaming endpoint |
| | 2 tasks | Automation (suspended until activated) |
| | 7 views | Monitoring dashboards |
| `STAGING_LAYER` | STG_BADGE_EVENTS | Deduplicated events |
| `ANALYTICS_LAYER` | DIM_USERS, DIM_ZONES | Dimensions (Type 2 SCD) |
| | FCT_ACCESS_EVENTS | Fact table (clustered) |

### Account-Level Objects

- **API Integration:** `SFE_GIT_API_INTEGRATION` (GitHub access)
- **Git Repository:** `DEMO_REPO.sfe_simple_stream_repo`

**Total Objects Created:** ~20 objects

---

## Monitoring

### 📊 Interactive Dashboard (Recommended)

**Deploy Streamlit dashboard (1 minute):**

```sql
@sql/05_streamlit/deploy_streamlit.sql
```

**Access:** Snowsight > Projects > Streamlit > `SFE_SIMPLE_STREAM_MONITOR`

**6 Interactive Pages:**
- 🎯 **Overview** - System health, KPIs, pipeline status
- 📈 **Ingestion Metrics** - Throughput charts, signal quality trends
- ⏱️ **Pipeline Health** - Layer-by-layer latency monitoring
- 💰 **Cost Tracking** - 30-day credit consumption analysis
- 🔧 **Task Performance** - Execution history, success rates
- 📊 **Query Efficiency** - Partition pruning analytics

**Dashboard guide:** [`docs/07-STREAMLIT-DASHBOARD.md`](docs/07-STREAMLIT-DASHBOARD.md)

---

### SQL Views (Programmatic Access)

Built-in views for custom queries and automation:

```sql
-- Ingestion rate (events per hour)
SELECT * FROM RAW_INGESTION.V_INGESTION_METRICS
ORDER BY ingestion_hour DESC LIMIT 24;

-- End-to-end latency (target: < 2 minutes)
SELECT * FROM RAW_INGESTION.V_END_TO_END_LATENCY;

-- Task execution health
SELECT * FROM RAW_INGESTION.V_TASK_EXECUTION_HISTORY
ORDER BY scheduled_time DESC LIMIT 10;

-- Data quality metrics (duplicates, orphans)
SELECT * FROM RAW_INGESTION.V_DATA_QUALITY_METRICS;

-- Cost tracking
SELECT * FROM RAW_INGESTION.V_STREAMING_COSTS
ORDER BY cost_date DESC LIMIT 30;
```

**Full SQL monitoring guide:** [`docs/04-MONITORING.md`](docs/04-MONITORING.md)

---

## Cleanup

Remove all demo objects:

```sql
@sql/99_cleanup/cleanup.sql
```

**What it does:**
- Drops all schemas (RAW_INGESTION, STAGING_LAYER, ANALYTICS_LAYER, DEMO_REPO)
- Removes all tables, streams, tasks, pipes, views
- Preserves `SNOWFLAKE_EXAMPLE` database (for audit)
- Preserves `SFE_GIT_API_INTEGRATION` (shared across demos)

**Time:** < 1 minute

---

## Requirements

### Snowflake Account
- **Roles:** ACCOUNTADMIN (for API integration), SYSADMIN (for objects)
- **Edition:** Standard or higher
- **Warehouse:** Any size (X-SMALL sufficient for demo)

### Network
- **Outbound HTTPS:443** to `github.com` (for Git repository access)
- **Outbound HTTPS:443** to `*.snowflakecomputing.com` (for Snowflake APIs)

### For Testing (Optional)
- Python 3.9+ (for event simulator)
- OpenSSL (for RSA key pair generation)

---

## Cost Estimate

**One-Time Setup:** < $0.01 (< 1 minute compute)

**Monthly Cost (Idle Demo):**
- Storage (~100 MB): < $0.03
- Task execution (1 min intervals): ~$1.50
- **Total:** < $2.00/month

**With Active Streaming (10,000 events/day):**
- Ingestion: < $0.01/day
- Tasks: ~$0.05/day
- **Total:** < $2.00/month

**Detailed cost breakdown:** [`docs/01-SETUP.md#cost-estimate`](docs/01-SETUP.md#cost-estimate)

---

## What Makes This Different

Most streaming examples are complex. This one is deliberately simple:

✅ **One-command deployment** (Git-integrated)  
✅ **Minimal objects** (only what's needed)  
✅ **Clear data flow** (raw → staging → analytics)  
✅ **Self-validating** (built-in health checks)  
✅ **Easy cleanup** (single script removes everything)  
✅ **Production patterns** (dimensional modeling, monitoring, cost tracking)

Perfect for **learning**, **demos**, and as a **template for production pipelines**.

---

## Documentation

### Getting Started (Internal)
- [`docs/01-SETUP.md`](docs/01-SETUP.md) - Prerequisites and account setup
- [`docs/02-DEPLOYMENT.md`](docs/02-DEPLOYMENT.md) - Deploy the pipeline (1 minute)
- [`docs/03-TESTING.md`](docs/03-TESTING.md) - Test with simulator (3 minutes automated)
- [`docs/04-MONITORING.md`](docs/04-MONITORING.md) - Monitor pipeline health (SQL views)
- [`docs/07-STREAMLIT-DASHBOARD.md`](docs/07-STREAMLIT-DASHBOARD.md) - **📊 Deploy interactive dashboard** (1 minute, native Snowflake)

### For External Data Providers
- [`docs/06-DATA-PROVIDER-QUICKSTART.md`](docs/06-DATA-PROVIDER-QUICKSTART.md) - **Send this to vendors** (10-minute integration guide)
- [`docs/05-API-HANDOFF.md`](docs/05-API-HANDOFF.md) - Complete API reference (troubleshooting, monitoring, advanced)

### Architecture
- [`diagrams/data-model.md`](diagrams/data-model.md) - Database schema and relationships
- [`diagrams/data-flow.md`](diagrams/data-flow.md) - Data transformation flow
- [`diagrams/network-flow.md`](diagrams/network-flow.md) - Network connectivity
- [`diagrams/auth-flow.md`](diagrams/auth-flow.md) - Authentication sequence

### SQL Scripts
```
sql/
├── 01_setup/
│   ├── 01_configure_auth.sql   ← Setup service account
│   └── 02_api_handoff.sql      ← Generate API docs
├── 02_core/
│   └── 01_core.sql             ← Raw table, pipe, stream
├── 03_transformations/
│   ├── 02_analytics.sql        ← Dimensions, facts
│   └── 03_tasks.sql            ← CDC automation
├── 04_monitoring/
│   └── 04_monitoring.sql       ← Monitoring SQL views
├── 05_streamlit/
│   └── deploy_streamlit.sql    ← 📊 Deploy dashboard (1 min)
└── 99_cleanup/
    └── cleanup.sql             ← Remove everything
```

### Streamlit Dashboard
- [`streamlit/README.md`](streamlit/README.md) - Dashboard documentation
- [`streamlit/streamlit_app.py`](streamlit/streamlit_app.py) - Main dashboard code
- [`streamlit/requirements.txt`](streamlit/requirements.txt) - Dependencies

---

## License

Reference implementation for educational and demonstration purposes.

⚠️ **NOT FOR PRODUCTION USE WITHOUT REVIEW** - Review and customize security, networking, and logic for your organization's specific requirements before deployment.

---

## Support

**Documentation:** See [`docs/`](docs/) directory  
**Issues:** File GitHub issues for bugs or feature requests  
**Architecture Questions:** Review [`diagrams/`](diagrams/) directory

---

**Ready to start?** → [`docs/01-SETUP.md`](docs/01-SETUP.md)
