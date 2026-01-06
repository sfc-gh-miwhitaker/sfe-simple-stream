# Quick Start - Simple Stream

Status: ACTIVE (timeboxed; expires 2026-02-05)

## Read Me First

This is a timeboxed demo repository. Deployment is blocked by `deploy_all.sql` after the expiration date.

## Deployment (Snowsight)

1. Open Snowsight and create a new SQL worksheet.
2. Copy the full contents of `deploy_all.sql` into the worksheet.
3. Click "Run All".

## Optional: Verify Existing Data (If Already Deployed Previously)

```sql
SELECT
  badge_id,
  user_id,
  zone_id,
  reader_id,
  event_timestamp,
  ingestion_time
FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS
ORDER BY ingestion_time DESC
LIMIT 10;
```

## Next Steps

Follow the numbered docs in `docs/` starting with `docs/01-SETUP.md`.
