![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--02--05-orange)

# Simple Streaming Pipeline (Snowpipe Streaming)

This repository is a **Snowflake-native reference implementation** for high-speed JSON event ingestion using **Snowpipe Streaming**, plus a small analytics layer and operational monitoring.

DEMONSTRATION PROJECT - ACTIVE (timeboxed)
Author: SE Community
Created: 2025-12-02 | Expires: 2026-02-05 | Status: ACTIVE

Deployment is **blocked by `deploy_all.sql` after the expiration date** (the expiration date is the single source of truth used by automation).

## What you get

- **Ingestion landing zone**: `SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS` (JSON events)
- **Automated processing**: stream + tasks to transform raw events into analytics tables
- **Operational monitoring**: monitoring views (health, freshness, latency, throughput, cost)
- **Optional dashboard**: a **native Streamlit app that runs in Snowflake** for real-time visibility
- **Clean teardown**: one SQL script removes demo objects while preserving `SNOWFLAKE_EXAMPLE`

## Deploy in Snowsight (45-60 seconds)

1. Open Snowsight and create a new SQL worksheet.
2. Copy the full contents of `deploy_all.sql` into the worksheet.
3. Click **Run All**.

Notes:
- **Warehouse**: tasks and Streamlit default to `COMPUTE_WH`. If your account doesn't have it, create it or adapt the warehouse in the SQL scripts.
- **Idempotent**: scripts are safe to re-run; the demo is designed for iterative walkthroughs.

## First time here? Pick your path

- **Snowflake admin / deployer**
  - Start with `QUICKSTART.md` (fastest deploy walkthrough)
  - Then read `docs/01-SETUP.md` and `docs/02-DEPLOYMENT.md`
- **Data provider / vendor integrating a stream**
  - Start with `docs/06-DATA-PROVIDER-QUICKSTART.md`
  - Then see `docs/05-API-HANDOFF.md` for the handoff contract and event format
- **Operator / analyst**
  - Start with `docs/04-MONITORING.md`
  - Optional: `docs/07-STREAMLIT-DASHBOARD.md` for the native dashboard

## Optional: deploy the native Streamlit dashboard

Run this in Snowsight after the core deployment:

```sql
@sql/05_streamlit/deploy_streamlit.sql
```

The app appears in Snowsight under **Projects -> Streamlit**.

## Clean up (teardown)

To remove demo objects:

```sql
@sql/99_cleanup/cleanup.sql
```

This removes the demo schemas and repo objects but **preserves** the `SNOWFLAKE_EXAMPLE` database and the shared API integration `SFE_GIT_API_INTEGRATION`.

## Architecture diagrams

Mermaid diagrams live in `diagrams/`:
- `diagrams/data-model.md`
- `diagrams/data-flow.md`
- `diagrams/network-flow.md`
- `diagrams/auth-flow.md`

## Repository layout

- `deploy_all.sql`: Snowsight "Run All" deployment entry point (enforces expiration)
- `sql/`: idempotent SQL scripts (core objects, transformations, monitoring, Streamlit, cleanup)
- `docs/`: numbered user guides (setup, deployment, testing, monitoring, security)
- `diagrams/`: architecture diagrams (Mermaid)
- `tools/`: optional local helpers (simulator orchestration)
- `simulator/`: optional event generator
- `streamlit/`: native Streamlit dashboard app (deployed inside Snowflake)
