# Quick Start - Simple Stream

**Time:** 2 minutes to running pipeline

---

## Prerequisites

- Snowflake account with ACCOUNTADMIN and SYSADMIN roles
- Snowsight open (web UI)

---

## Deploy (45 seconds)

Copy/paste this into a Snowsight worksheet and click "Run All":

```sql
@deploy_all.sql
```

✅ **Done!** Pipeline is deployed.

---

## Verify (10 seconds)

```sql
(validation automatic in deploy_all.sql)
```

Expected output: All checks pass (✓)

---

## Test (Optional - 10 minutes)

**Full testing instructions:** [`docs/03-TESTING.md`](docs/03-TESTING.md)

**Quick test:**
1. Configure auth: `@sql/01_setup/01_configure_auth.sql`
2. Generate RSA keys (see testing guide)
3. Run simulator: `cd simulator && ./send_events.sh`
4. View data: `SELECT * FROM RAW_INGESTION.RAW_BADGE_EVENTS LIMIT 10;`

---

## Monitor

```sql
-- Live ingestion metrics
SELECT * FROM RAW_INGESTION.V_INGESTION_METRICS;

-- Pipeline health
SELECT * FROM RAW_INGESTION.V_END_TO_END_LATENCY;
```

**Full monitoring guide:** [`docs/04-MONITORING.md`](docs/04-MONITORING.md)

---

## Cleanup

```sql
@sql/99_cleanup/cleanup.sql
```

---

## Next Steps

For complete setup instructions, see [`docs/01-SETUP.md`](docs/01-SETUP.md)

For architecture details, see [`diagrams/`](diagrams/) directory

For full documentation, see [`README.md`](README.md)

