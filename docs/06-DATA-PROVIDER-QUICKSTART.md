# Data Provider Quickstart - Stream Events in 10 Minutes

**Target:** External data providers/vendors who need to stream badge events into Snowflake

**Time:** ~10 minutes

---

## What You'll Receive

Your Snowflake administrator will provide a **credentials package** containing:

```
📦 Credentials Package
├── account: myorg-myaccount
├── user: SFE_INGEST_USER
├── private_key: rsa_key.p8 file
├── database: SNOWFLAKE_EXAMPLE
├── schema: RAW_INGESTION
└── table: RAW_BADGE_EVENTS
```

**Keep the private key secure** - it's your only authentication credential (no passwords needed).

---

## 5-Minute Integration (Python Example)

### Step 1: Install SDK (1 minute)

```bash
pip install snowflake-ingest
```

**SDK available for:** Python, Java, Node.js

---

### Step 2: Write Integration Code (3 minutes)

```python
from snowflake.ingest import SimpleIngestManager

# Configuration (from credentials package)
ACCOUNT = 'myorg-myaccount'  # Provided by admin
USER = 'SFE_INGEST_USER'     # Provided by admin
PRIVATE_KEY_PATH = 'rsa_key.p8'  # File provided by admin
DATABASE = 'SNOWFLAKE_EXAMPLE'
SCHEMA = 'RAW_INGESTION'
TABLE = 'RAW_BADGE_EVENTS'

# Initialize SDK
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

# Prepare event (JSON format)
event = {
    "badge_id": "BADGE-001",           # Required
    "user_id": "USR-001",              # Required
    "zone_id": "ZONE-LOBBY-1",         # Required
    "reader_id": "RDR-101",            # Required
    "event_timestamp": "2024-11-24T10:30:00",  # Required (ISO 8601)
    "signal_strength": -65.5,          # Optional (dBm)
    "direction": "ENTRY"               # Optional ("ENTRY" or "EXIT")
}

# Stream event
response = manager.ingest_rows([event])
print("✅ Event sent successfully")
```

**That's it.** SDK handles all authentication, buffering, compression, and retry logic automatically.

---

### Step 3: Verify (1 minute)

Ask your Snowflake administrator to run:

```sql
SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS
WHERE badge_id = 'BADGE-001'
ORDER BY ingestion_time DESC;
```

**Expected:** Your event appears within 1-2 minutes.

---

## JSON Event Format (Required Fields)

**Every event must include these 5 fields:**

```json
{
  "badge_id": "BADGE-001",                    // STRING - Badge/card ID
  "user_id": "USR-001",                       // STRING - User ID
  "zone_id": "ZONE-LOBBY-1",                  // STRING - Zone/location ID
  "reader_id": "RDR-101",                     // STRING - RFID reader ID
  "event_timestamp": "2024-11-24T10:30:00"    // STRING - ISO 8601 timestamp
}
```

**Optional fields for richer data:**

```json
{
  "signal_strength": -65.5,    // NUMBER - RSSI in dBm
  "direction": "ENTRY"         // STRING - "ENTRY" or "EXIT"
}
```

**Timestamp format requirements:**
- ✅ `"2024-11-24T10:30:00"` - ISO 8601 (required)
- ✅ `"2024-11-24T10:30:00Z"` - with timezone
- ✅ `"2024-11-24T10:30:00-05:00"` - with offset
- ❌ `"11/24/2024 10:30 AM"` - NOT accepted
- ❌ `"2024-11-24 10:30:00"` - NOT accepted (space instead of T)

---

## What Happens Automatically

**Snowflake pipeline enriches your data:**

1. **Signal Quality Classification** (if you provide `signal_strength`):
   - `< -80 dBm` → `"WEAK"`
   - `-80 to -60 dBm` → `"MEDIUM"`
   - `> -60 dBm` → `"STRONG"`

2. **Ingestion Timestamp** - Server timestamp added automatically

3. **Additional Fields** - Any extra JSON fields preserved for future analysis

---

## Production Deployment Checklist

- [ ] Store private key securely (environment variable or vault, not in code)
- [ ] Implement error handling (SDK auto-retries, but log failures)
- [ ] Monitor SDK response for errors
- [ ] Batch events for efficiency (SDK handles automatically)
- [ ] Verify network access to `*.snowflakecomputing.com:443` (HTTPS)
- [ ] Test with `badge_id` prefix "TEST-" first
- [ ] Coordinate go-live with Snowflake administrator

---

## Batch Events for Higher Throughput

**For high-volume streaming (>100 events/sec):**

```python
# Collect events in batches
events = [
    {"badge_id": "BADGE-001", "user_id": "USR-001", ...},
    {"badge_id": "BADGE-002", "user_id": "USR-002", ...},
    # ... up to 10,000 events per batch
]

# Send batch
manager.ingest_rows(events)
```

**SDK optimizes automatically:**
- Compression
- Buffering
- Parallel uploads
- Connection pooling

**Typical throughput:** Millions of events/second (SDK handles scaling)

---

## Troubleshooting

### "Authentication failed"

**Cause:** Private key doesn't match public key registered in Snowflake

**Fix:** Verify you're using the correct `rsa_key.p8` file provided by admin. Do NOT generate your own key.

---

### "Connection timeout"

**Cause:** Network firewall blocking HTTPS to Snowflake

**Fix:** Verify outbound HTTPS:443 allowed to `*.snowflakecomputing.com`

---

### "Events not appearing"

**Cause:** Query timing (data takes ~1 minute to be queryable)

**Fix:** Wait 2 minutes, then query again. Events are durable - they won't be lost.

---

## Performance & SLAs

| Metric | Value |
|--------|-------|
| **Typical Latency** | < 1 minute (event sent → queryable) |
| **Max Throughput** | Millions of events/sec |
| **Durability** | Once SDK reports success, event is durable |
| **Event Size Limit** | < 100 KB/event |

---

## SDK Reference Documentation

**Python:**
- [Python SDK Quickstart](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-python)
- [API Reference](https://docs.snowflake.com/en/developer-guide/snowpipe-streaming/python-api)

**Java:**
- [Java SDK Quickstart](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-java)

**Node.js:**
- [Node.js SDK Quickstart](https://docs.snowflake.com/en/user-guide/data-load-snowpipe-streaming-nodejs)

---

## Support Contacts

**Snowflake Administrator:** [Provided separately]  
**Pipeline Owner:** [Provided separately]  
**Escalation:** [Provided separately]

---

## Common Questions

**Q: Do I need to generate JWT tokens?**  
A: No, SDK handles all authentication automatically.

**Q: What if my connection drops?**  
A: SDK automatically retries with exponential backoff.

**Q: Can I test without impacting production?**  
A: Yes, use test badge IDs (prefix: "TEST-") and coordinate with admin.

**Q: How do I monitor ingestion?**  
A: Ask your Snowflake admin for monitoring dashboard access. They have real-time metrics.

**Q: Can I send custom fields beyond the required 5?**  
A: Yes, any additional JSON fields are preserved in `raw_json` column.

---

## Next Steps

1. **Receive credentials** from Snowflake administrator
2. **Install SDK** in your environment
3. **Send test event** with `badge_id = "TEST-VENDOR-001"`
4. **Verify with admin** that test event landed
5. **Deploy to production** after successful test

---

**Ready to integrate?** Contact your Snowflake administrator to receive your credentials package.

**Need detailed reference?** See [`05-API-HANDOFF.md`](05-API-HANDOFF.md) for complete API documentation.

