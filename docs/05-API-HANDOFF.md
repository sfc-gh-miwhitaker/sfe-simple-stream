# Data Provider Integration Guide

**Target Database:** `SNOWFLAKE_EXAMPLE`  
**Target Schema:** `RAW_INGESTION`  
**Target Table:** `RAW_BADGE_EVENTS`

**Purpose:** This document provides everything a data provider needs to stream events into your Snowflake pipeline.

---

## 🎯 Quick Start: Send Your First Event in 5 Minutes

**Snowflake provides official SDKs that handle all authentication automatically:**

### Step 1: Install SDK

**Python:**
```bash
pip install snowflake-ingest
```

**Java:**
```xml
<dependency>
  <groupId>net.snowflake</groupId>
  <artifactId>snowflake-ingest-sdk</artifactId>
  <version>2.1.0</version>
</dependency>
```

**Node.js:**
```bash
npm install @snowflake/ingest-sdk
```

### Step 2: Get Your Credentials

**You need these 3 items** (provided by Snowflake admin):
1. **Account Identifier** - Format: `orgname-accountname` (e.g., `acme-prod01`)
2. **Username** - Service account username (e.g., `SFE_INGEST_USER`)
3. **Private Key File** - RSA private key file (`.p8` or `.pem` format)

**Example credentials package:**
```
account: myorg-myaccount
user: SFE_INGEST_USER
private_key: /path/to/rsa_key.p8
database: SNOWFLAKE_EXAMPLE
schema: RAW_INGESTION
table: RAW_BADGE_EVENTS
```

### Step 3: Stream Events

**Complete Python Example:**

```python
from snowflake.ingest import SimpleIngestManager
from pathlib import Path

# Configuration
ACCOUNT = 'myorg-myaccount'
USER = 'SFE_INGEST_USER'
PRIVATE_KEY_PATH = 'keys/rsa_key.p8'
DATABASE = 'SNOWFLAKE_EXAMPLE'
SCHEMA = 'RAW_INGESTION'
TABLE = 'RAW_BADGE_EVENTS'

# Initialize SDK (handles all authentication automatically)
with open(PRIVATE_KEY_PATH, 'r') as f:
    private_key = f.read()

manager = SimpleIngestManager(
    account=ACCOUNT,
    user=USER,
    private_key=private_key,
    database=DATABASE,
    schema=SCHEMA,
    table=TABLE
)

# Prepare your events (JSON format)
events = [
    {
        "badge_id": "BADGE-001",
        "user_id": "USR-001",
        "zone_id": "ZONE-LOBBY-1",
        "reader_id": "RDR-101",
        "event_timestamp": "2024-11-24T10:30:00",
        "signal_strength": -65.5,
        "direction": "ENTRY"
    },
    {
        "badge_id": "BADGE-002",
        "user_id": "USR-002",
        "zone_id": "ZONE-OFFICE-201",
        "reader_id": "RDR-102",
        "event_timestamp": "2024-11-24T10:31:00",
        "signal_strength": -72.0,
        "direction": "EXIT"
    }
]

# Send events (SDK handles buffering, compression, REST API calls)
response = manager.ingest_rows(events)
print(f"✅ Successfully sent {len(events)} events")
```

**That's it.** No JWT tokens, no fingerprint calculation, no manual REST calls. The SDK handles everything.

### What the SDK Does Automatically

✅ **Zero Authentication Code** - SDK calculates JWT tokens internally  
✅ **High Performance** - Rust-based core optimized for millions of events/second  
✅ **Official Support** - Maintained by Snowflake engineering  
✅ **Automatic Retry** - Built-in error handling and reconnection  
✅ **Simplified Config** - Just provide account/user/private_key

---

## Alternative: REST API (Not Recommended)

**Use REST API only if:**
- Lightweight IoT/edge devices with severe memory constraints
- Languages without SDK support (though Java/Python/Node cover 95% of cases)
- Custom protocol implementations requiring low-level control

**For REST API:** See [Appendix A: REST API Reference](#appendix-a-rest-api-reference) at bottom of this document.

---

## Connection Details (Provided by Snowflake Admin)

**You will receive these credentials from your Snowflake administrator:**

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Account Identifier** | `<orgname>-<accountname>` | Example: `acme-prod01` |
| **Account URL** | `<orgname>-<accountname>.snowflakecomputing.com` | For REST API only |
| **Database** | `SNOWFLAKE_EXAMPLE` | Target database |
| **Schema** | `RAW_INGESTION` | Target schema |
| **Table** | `RAW_BADGE_EVENTS` | Target table |
| **User** | `SFE_INGEST_USER` | Service account username |
| **Private Key** | `rsa_key.p8` file | RSA private key (keep secure) |

**Example credentials file:**

```json
{
  "account": "acme-prod01",
  "user": "SFE_INGEST_USER",
  "private_key_path": "/secure/keys/rsa_key.p8",
  "database": "SNOWFLAKE_EXAMPLE",
  "schema": "RAW_INGESTION",
  "table": "RAW_BADGE_EVENTS"
}
```

**⚠️ Security Notes:**
- Keep the private key file secure (never commit to Git, never email unencrypted)
- Use environment variables or secure vaults for production deployments
- The private key is the only authentication credential needed (no passwords)

---

## JSON Event Format

### Required Fields (Must Include)

**Every event must contain these 5 fields:**

| Field | Type | Description | Example | Validation |
|-------|------|-------------|---------|------------|
| `badge_id` | STRING | Unique badge/card identifier | `"BADGE-001"` | Not null, max 50 chars |
| `user_id` | STRING | User identifier | `"USR-001"` | Not null, max 50 chars |
| `zone_id` | STRING | Zone/location identifier | `"ZONE-LOBBY-1"` | Not null, max 50 chars |
| `reader_id` | STRING | RFID reader identifier | `"RDR-101"` | Not null, max 50 chars |
| `event_timestamp` | STRING | Event time (ISO 8601) | `"2024-11-24T10:30:00"` | ISO 8601 format required |

**Timestamp Format Requirements:**
- ✅ **Accepted:** `"2024-11-24T10:30:00"` (ISO 8601)
- ✅ **Accepted:** `"2024-11-24T10:30:00Z"` (with timezone)
- ✅ **Accepted:** `"2024-11-24T10:30:00-05:00"` (with offset)
- ❌ **Rejected:** `"11/24/2024 10:30 AM"` (not ISO 8601)
- ❌ **Rejected:** `"2024-11-24 10:30:00"` (space instead of T)

### Optional Fields (Enhance with Additional Data)

| Field | Type | Description | Example | Default if Missing |
|-------|------|-------------|---------|-------------------|
| `signal_strength` | NUMBER | RSSI in dBm | `-65.5` | `-999` |
| `direction` | STRING | Entry or exit | `"ENTRY"` or `"EXIT"` | `null` |

### Example Event (Complete)

```json
{
  "badge_id": "BADGE-001",
  "user_id": "USR-001",
  "zone_id": "ZONE-LOBBY-1",
  "reader_id": "RDR-101",
  "event_timestamp": "2024-11-24T10:30:00",
  "signal_strength": -65.5,
  "direction": "ENTRY"
}
```

### Automatic Server-Side Transformations

**Snowflake pipeline automatically enriches your data:**

1. **Signal Quality Classification** (based on `signal_strength`):
   - `< -80 dBm` → `"WEAK"`
   - `-80 to -60 dBm` → `"MEDIUM"`
   - `> -60 dBm` → `"STRONG"`

2. **Direction Normalization:**
   - Converts to uppercase (`"entry"` → `"ENTRY"`)

3. **Ingestion Timestamp:**
   - `ingestion_time` automatically added (server time when received)

4. **Additional Fields Storage:**
   - Any extra JSON fields preserved in `raw_json` column for future analysis

---

## Verify Your Integration

### Step 1: Send Test Event

**Use the SDK example above with a test badge ID:**

```python
test_event = {
    "badge_id": "TEST-VENDOR-001",
    "user_id": "USR-001",
    "zone_id": "ZONE-LOBBY-1",
    "reader_id": "RDR-101",
    "event_timestamp": "2024-11-24T10:30:00",
    "signal_strength": -65.5,
    "direction": "ENTRY"
}

manager.ingest_rows([test_event])
```

### Step 2: Verify Data Landed

**Ask your Snowflake administrator to run this query:**

```sql
SELECT 
    badge_id,
    user_id,
    zone_id,
    event_timestamp,
    signal_strength,
    signal_quality,
    ingestion_time
FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS 
WHERE badge_id = 'TEST-VENDOR-001'
ORDER BY ingestion_time DESC 
LIMIT 10;
```

**Expected Result:**
- ✅ Row appears within 2 minutes of sending
- ✅ `signal_quality` is automatically calculated (`"MEDIUM"` for -65.5 dBm)
- ✅ `ingestion_time` is populated with server timestamp

---

## Monitoring & Health Checks

**Your Snowflake administrator has access to these monitoring views:**

### Ingestion Rate Metrics

```sql
-- Events per hour over last 24 hours
SELECT * 
FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_INGESTION_METRICS
ORDER BY ingestion_hour DESC 
LIMIT 24;
```

**Shows:** Events received per hour, average rate per minute, data volume

### End-to-End Latency

```sql
-- How long from ingestion to analytics
SELECT * 
FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_END_TO_END_LATENCY;
```

**Expected:** < 2 minutes from event sent to queryable in analytics layer

### Data Quality Metrics

```sql
-- Check for duplicates, orphans, signal quality distribution
SELECT * 
FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_DATA_QUALITY_METRICS;
```

**Use these metrics to:**
- Verify events are flowing continuously
- Detect latency issues
- Identify data quality problems (bad timestamps, unknown user_ids, etc.)

---

## Performance & Capacity

| Metric | Value | Notes |
|--------|-------|-------|
| **Max Throughput** | Millions of events/sec | Snowpipe Streaming capacity |
| **Typical Latency** | < 1 minute | Event sent → queryable in RAW table |
| **End-to-End Latency** | < 2 minutes | Event sent → enriched in ANALYTICS layer |
| **Event Size** | < 100 KB/event | Typical badge event ~500 bytes |
| **Batch Size** | 10-16 MB (compressed) | SDK handles automatically |

**Optimization Tips:**
- SDK batches events automatically for optimal performance
- No need to implement custom batching logic
- SDK uses compression automatically
- For very high volumes (>100K events/sec), contact Snowflake support for tuning

---

## Troubleshooting

### Authentication Errors

**Symptom:** `Authentication failed` or `JWT token invalid`

**Causes:**
- Private key doesn't match public key registered in Snowflake
- User doesn't have INSERT privilege on table
- Account identifier is incorrect

**Resolution:**
1. Verify account identifier format: `orgname-accountname` (not URL)
2. Confirm private key file path is correct
3. Ask Snowflake admin to verify user privileges:
   ```sql
   SHOW GRANTS TO ROLE sfe_ingest_role;
   ```

### Events Not Appearing

**Symptom:** SDK reports success, but queries return no data

**Causes:**
- Query timing (data takes ~1 minute to be queryable)
- Wrong table being queried
- Badge IDs don't match query filter

**Resolution:**
1. Wait 1-2 minutes after sending
2. Verify table name: `SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS`
3. Check without filters: `SELECT COUNT(*) FROM RAW_BADGE_EVENTS;`

### Network/Connectivity Issues

**Symptom:** Connection timeout or network errors

**Causes:**
- Firewall blocking HTTPS:443 to `*.snowflakecomputing.com`
- DNS resolution issues
- Proxy configuration required

**Resolution:**
1. Verify outbound HTTPS allowed to `*.snowflakecomputing.com`
2. Test basic connectivity: `curl https://<account>.snowflakecomputing.com`
3. Configure proxy settings if required (SDK supports proxy environment variables)

---

## Support & Contacts

**Technical Questions:**
- Snowflake Administrator: [Contact provided separately]
- Pipeline Owner: [Contact provided separately]

**Snowflake Documentation:**
- [Snowpipe Streaming Overview](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-overview)
- [Python SDK Reference](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-python)
- [Java SDK Reference](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-java)

**Common Questions:**
- **Q: Do I need to manage JWT tokens?**  
  A: No, the SDK handles all authentication automatically.
  
- **Q: What happens if my connection drops mid-stream?**  
  A: SDK automatically retries and resumes from last successful batch.
  
- **Q: Can I send events from multiple processes?**  
  A: Yes, SDK is thread-safe and supports concurrent streaming.
  
- **Q: How do I handle schema changes?**  
  A: Additional JSON fields are automatically preserved in `raw_json` column. Coordinate with Snowflake admin for formal schema updates.

---

## Appendix A: REST API Reference

**⚠️ NOT RECOMMENDED - Use SDK Instead**

If you absolutely must use the REST API (IoT device, unsupported language), see the complete REST API authentication flow below.

<details>
<summary>Click to expand REST API details (advanced users only)</summary>

### REST Endpoint

```
POST https://<account>.snowflakecomputing.com/v1/data/pipes/<pipe>/insertRows
```

### Authentication Flow (Manual JWT Generation)

1. Calculate RSA public key fingerprint (SHA256)
2. Generate JWT token with claims:
   - `iss`: `<account>.<user>.<fingerprint>`
   - `sub`: `<account>.<user>`
   - `iat`: Current Unix timestamp
   - `exp`: Expiration (< 1 hour)
3. Sign JWT with RSA private key
4. Include in Authorization header: `Bearer <jwt_token>`

**Example cURL:**

```bash
curl -X POST \
  "https://myorg-myaccount.snowflakecomputing.com/v1/data/pipes/SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE/insertRows" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '[{"badge_id":"TEST-001","user_id":"USR-001","zone_id":"ZONE-LOBBY-1","reader_id":"RDR-101","event_timestamp":"2024-11-24T10:30:00"}]'
```

**Why SDK is Better:**
- 200+ lines of JWT code → 5 lines of SDK config
- Manual token refresh → Automatic refresh
- Error-prone fingerprint calculation → Handled internally
- No retry logic → Built-in exponential backoff

</details>

