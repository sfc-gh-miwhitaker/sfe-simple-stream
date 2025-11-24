# Setup Guide - Simple Stream

**Time to Complete:** ~5 minutes  
**Prerequisites:** Snowflake account with ACCOUNTADMIN and SYSADMIN roles

---

## Purpose

This guide walks you through the prerequisites and account setup required before deploying the Simple Stream pipeline.

## Prerequisites

### Required Snowflake Roles

| Role | Purpose | Required For |
|------|---------|--------------|
| **ACCOUNTADMIN** | Create API integration (one-time) | Git repository access setup |
| **SYSADMIN** | Create databases, schemas, objects | Pipeline deployment |

**Verification:**
```sql
SHOW GRANTS TO USER CURRENT_USER();
```

You should see both `ACCOUNTADMIN` and `SYSADMIN` in the results.

### Required Snowflake Edition

| Edition | Supported | Notes |
|---------|-----------|-------|
| Standard | ✅ Yes | All features supported |
| Enterprise | ✅ Yes | Recommended (includes fail-safe) |
| Business Critical | ✅ Yes | Enhanced security features |

**Verification:**
```sql
SELECT CURRENT_ACCOUNT(), CURRENT_REGION();
```

### Network Requirements

**Outbound Connectivity:**
- Destination: `github.com` (for Git repository access)
- Port: 443 (HTTPS)
- Protocol: TCP

**Snowflake Endpoints:**
- Account URL: `https://orgname-accountname.snowflakecomputing.com`
- Ingest Host: Discovered automatically via API

No inbound connectivity required (all client-initiated).

---

## Account Configuration

### 1. Verify Warehouse Exists

The pipeline uses the default `COMPUTE_WH` warehouse. Verify it exists:

```sql
SHOW WAREHOUSES LIKE 'COMPUTE_WH';
```

**Expected Output:**
- State: STARTED or SUSPENDED (both OK)
- Size: Any size (X-SMALL recommended for demo)

**If warehouse doesn't exist:**
```sql
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Default compute warehouse';
```

### 2. Verify GitHub Connectivity

Test outbound HTTPS to GitHub:

```sql
-- This will be used in deployment for Git repository access
SELECT SYSTEM$WHITELIST_PRIVATELINK();
```

If your account has network policies, ensure `github.com` is allowed.

### 3. Check Current Context

Verify your current session context:

```sql
SELECT 
    CURRENT_ROLE() AS role,
    CURRENT_USER() AS user,
    CURRENT_WAREHOUSE() AS warehouse,
    CURRENT_ACCOUNT() AS account,
    CURRENT_REGION() AS region;
```

**Expected:**
- Role: Should have ACCOUNTADMIN or SYSADMIN
- Warehouse: COMPUTE_WH (or any available warehouse)
- Account: Your organization-account identifier
- Region: Your account's cloud region

---

## What You'll Create

The deployment will create these objects:

### Account-Level Objects (Require ACCOUNTADMIN)

| Object Type | Name | Purpose |
|-------------|------|---------|
| API Integration | `SFE_GIT_API_INTEGRATION` | GitHub repository access |

### Database & Schema Objects

| Object Type | Location | Purpose |
|-------------|----------|---------|
| Database | `SNOWFLAKE_EXAMPLE` | Container for demo objects |
| Schema | `RAW_INGESTION` | Raw landing layer |
| Schema | `STAGING_LAYER` | Deduplication layer |
| Schema | `ANALYTICS_LAYER` | Analytics ready data |
| Schema | `DEMO_REPO` | Git repository stage |
| Git Repository | `DEMO_REPO.sfe_simple_stream_repo` | GitHub connection |

### Data Pipeline Objects

| Type | Count | Examples |
|------|-------|----------|
| Tables | 5 | RAW_BADGE_EVENTS, STG_BADGE_EVENTS, FCT_ACCESS_EVENTS |
| Streams | 1 | sfe_badge_events_stream |
| Tasks | 2 | sfe_raw_to_staging_task, sfe_staging_to_analytics_task |
| Pipes | 1 | sfe_badge_events_pipe |
| Views | 7 | V_INGESTION_METRICS, V_END_TO_END_LATENCY, etc. |

**Total Objects:** ~20 objects created

---

## Security Considerations

### Principle of Least Privilege

The pipeline is designed with minimal privileges:
- Uses SYSADMIN for all object creation (not ACCOUNTADMIN)
- ACCOUNTADMIN only needed for API integration (one-time setup)
- Service account (created later) has INSERT-only privileges

### API Integration Security

The Git API integration:
- ✅ Limited to `https://github.com/` prefix only
- ✅ Public repository (no credentials stored)
- ✅ Read-only access (Snowflake pulls scripts, doesn't push)
- ✅ Can be shared across multiple demo projects

### Data Isolation

All demo objects use the `SFE_` prefix (SnowFlake Example):
- Easy to identify demo vs. production objects
- Simple cleanup (drop all SFE_* objects)
- No collision risk with existing objects

---

## Cost Estimate

### One-Time Setup Cost
- **Deployment:** < $0.01 (< 1 minute of X-SMALL warehouse time)
- **API Integration:** Free (no compute cost)
- **Git Repository:** Free (no compute cost)

### Ongoing Cost (Demo Scenario)

| Component | Daily Cost | Monthly Cost |
|-----------|-----------|--------------|
| Storage (~100 MB) | < $0.001 | < $0.03 |
| Task Execution (1 min intervals) | ~$0.05 | ~$1.50 |
| Snowpipe Streaming | $0 | $0 (no demo data) |

**Total Monthly Cost:** < $2.00 for idle demo (no active streaming)

**With Active Streaming (10,000 events/day):**
- Ingestion: < $0.01/day
- Tasks: ~$0.05/day
- **Total:** < $2/month

---

## Troubleshooting

### "ACCOUNTADMIN role required"

**Symptom:** Error creating API integration  
**Cause:** Using SYSADMIN for API integration creation  
**Fix:** Switch roles:
```sql
USE ROLE ACCOUNTADMIN;
```

### "Access to GitHub is blocked"

**Symptom:** Git repository creation fails  
**Cause:** Network policy or firewall blocking github.com  
**Fix:** Verify outbound HTTPS:443 to github.com is allowed

### "Warehouse COMPUTE_WH does not exist"

**Symptom:** Deployment fails with warehouse error  
**Cause:** Default warehouse not created  
**Fix:** Create warehouse (see step 1 above)

### "Insufficient privileges"

**Symptom:** Cannot create database or schema  
**Cause:** User lacks SYSADMIN role  
**Fix:** Grant role:
```sql
USE ROLE ACCOUNTADMIN;
GRANT ROLE SYSADMIN TO USER <your_username>;
```

---

## Pre-Deployment Checklist

Before proceeding to deployment, verify:

- [ ] You have ACCOUNTADMIN role access
- [ ] You have SYSADMIN role access
- [ ] COMPUTE_WH warehouse exists (or equivalent)
- [ ] Outbound HTTPS to github.com is allowed
- [ ] You understand the objects that will be created
- [ ] You've reviewed the cost estimate
- [ ] You're ready to proceed with deployment

**Estimated Total Setup Time:** 5 minutes

---

## Next Steps

✅ **Setup Complete!**

Proceed to deployment:

**→ Next:** [`02-DEPLOYMENT.md`](02-DEPLOYMENT.md) - Deploy the pipeline (1 minute)

**Alternative:** Review architecture diagrams first:
- [`../diagrams/data-model.md`](../diagrams/data-model.md) - Database schema
- [`../diagrams/data-flow.md`](../diagrams/data-flow.md) - Data transformation flow
- [`../diagrams/network-flow.md`](../diagrams/network-flow.md) - Network architecture
- [`../diagrams/auth-flow.md`](../diagrams/auth-flow.md) - Authentication flow

---

## Related Documentation

### Internal Team
- [`02-DEPLOYMENT.md`](02-DEPLOYMENT.md) - Next: Deploy the pipeline
- [`03-TESTING.md`](03-TESTING.md) - How to send test events
- [`04-MONITORING.md`](04-MONITORING.md) - Monitor pipeline health

### External Data Providers
- [`06-DATA-PROVIDER-QUICKSTART.md`](06-DATA-PROVIDER-QUICKSTART.md) - **Send to vendors** (10-minute integration)
- [`05-API-HANDOFF.md`](05-API-HANDOFF.md) - Complete API reference

