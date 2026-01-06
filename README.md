![Reference Implementation](https://img.shields.io/badge/Reference-Implementation-blue)
![Ready to Run](https://img.shields.io/badge/Ready%20to%20Run-Yes-green)
![Expires](https://img.shields.io/badge/Expires-2026--02--05-orange)

# Simple Stream

DEMONSTRATION PROJECT - ACTIVE (timeboxed)

This demo uses Snowflake features current as of December 2025. It is timeboxed to prevent users from encountering outdated syntax or deprecated features.

Author: SE Community
Purpose: Reference implementation for high-speed data ingestion with Snowpipe Streaming
Created: 2025-12-02 | Expires: 2026-02-05 | Status: ACTIVE

## First Time Here?

Deployment is blocked by `deploy_all.sql` after the expiration date.

Read these in order:
1. `docs/01-SETUP.md` - Prereqs and account setup
2. `docs/02-DEPLOYMENT.md` - Deployment flow and what gets created
3. `docs/03-TESTING.md` - Optional simulator-based testing
4. `docs/04-MONITORING.md` - Monitoring views and operational checks
5. `docs/07-STREAMLIT-DASHBOARD.md` - Native Streamlit dashboard
6. `sql/99_cleanup/cleanup.sql` - Teardown

## Repository Layout

- `deploy_all.sql`: Snowsight "Run All" deployment entry point (enforces expiration)
- `sql/`: Idempotent SQL scripts for core objects, transformations, monitoring, and cleanup
- `docs/`: Numbered user guides
- `diagrams/`: Mandatory Mermaid architecture diagrams
- `tools/`: Optional local helpers (key generation + simulator orchestration)
- `simulator/`: Optional event generator
- `streamlit/`: Native Streamlit dashboard app (deployed inside Snowflake)
