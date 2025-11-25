# Streamlit Dashboard

**Native Snowflake Streamlit App for Real-Time Monitoring**

---

## Files

| File | Purpose |
|------|---------|
| `streamlit_app.py` | Main dashboard application code |
| `requirements.txt` | Python dependencies (plotly, pandas, numpy) |

---

## Deployment

**Deploy to Snowflake (1 minute):**

```sql
@sql/05_streamlit/deploy_streamlit.sql
```

**What it does:**
1. Creates stage `SFE_STREAMLIT_STAGE`
2. Copies files from Git repo → stage
3. Creates Streamlit app `SFE_SIMPLE_STREAM_MONITOR`
4. Grants access permissions

**Access:** Snowsight → Projects → Streamlit → `SFE_SIMPLE_STREAM_MONITOR`

---

## Development

### Local Testing (Optional)

You can test the Streamlit app locally before deploying to Snowflake:

```bash
# Install dependencies
pip install -r requirements.txt

# Note: For local testing, you'll need to modify the connection logic
# in streamlit_app.py from:
#   session = get_active_session()
# to:
#   conn = st.connection("snowflake")
#   session = conn.session()

# Run locally
streamlit run streamlit_app.py
```

**For production deployment, always use the native Snowflake deployment via SQL.**

---

## Architecture

**Deployment Flow:**
```
Git Repository (sfe-simple-stream)
  └─ streamlit/
      ├─ streamlit_app.py
      └─ requirements.txt
            ↓
        COPY FILES
            ↓
    SFE_STREAMLIT_STAGE
            ↓
     CREATE STREAMLIT
            ↓
  SFE_SIMPLE_STREAM_MONITOR
  (Runs in Snowflake)
```

**Data Sources:**
- `V_CHANNEL_STATUS` - Streaming ingestion health
- `V_INGESTION_METRICS` - Hourly throughput metrics
- `V_END_TO_END_LATENCY` - Pipeline latency tracking
- `V_DATA_FRESHNESS` - Table freshness metrics
- `V_PARTITION_EFFICIENCY` - Query pruning analytics
- `V_STREAMING_COSTS` - Cost tracking
- `V_TASK_EXECUTION_HISTORY` - Task performance

---

## Dashboard Features

### 🎯 Overview Page
- System health KPIs
- Pipeline status indicators
- Data freshness metrics

### 📈 Ingestion Metrics
- Events over time chart
- Entry vs Exit comparison
- Signal quality trends

### ⏱️ Pipeline Health
- Layer-by-layer latency
- Health status cards
- Row count visualization

### 💰 Cost Tracking
- 30-day credit consumption
- Data volume trends
- Ingestion efficiency

### 🔧 Task Performance
- Success rate by task
- Duration over time
- Status distribution

### 📊 Query Efficiency
- Partition pruning metrics
- Scan ratio by table
- Efficiency ratings

---

## Customization

Edit `streamlit_app.py` to add custom views or modify existing ones.

**Example: Add custom metric**

```python
# Add after existing pages
elif page == "🆕 Custom View":
    st.header("My Custom View")
    
    custom_df = query_snowflake("""
        SELECT 
            badge_id,
            COUNT(*) AS event_count
        FROM RAW_BADGE_EVENTS
        WHERE ingestion_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
        GROUP BY badge_id
        ORDER BY event_count DESC
        LIMIT 10
    """)
    
    st.dataframe(custom_df)
```

After modifying, redeploy:
```sql
@sql/05_streamlit/deploy_streamlit.sql
```

---

## Documentation

**Complete guide:** [`../docs/07-STREAMLIT-DASHBOARD.md`](../docs/07-STREAMLIT-DASHBOARD.md)

**Deployment script:** [`../sql/05_streamlit/deploy_streamlit.sql`](../sql/05_streamlit/deploy_streamlit.sql)

---

## Troubleshooting

**Dashboard shows errors:**
- Verify monitoring views exist: `@sql/04_monitoring/04_monitoring.sql`
- Check warehouse is running: `SHOW WAREHOUSES LIKE 'COMPUTE_WH'`

**Can't find app in Snowsight:**
- Verify deployment succeeded: `SHOW STREAMLITS IN SCHEMA RAW_INGESTION`
- Check access: `SHOW GRANTS TO ROLE YOUR_ROLE`

**Need to redeploy:**
```sql
-- Re-run deployment (pulls latest from Git)
@sql/05_streamlit/deploy_streamlit.sql
```

---

**Author:** SE Community  
**Purpose:** Real-time monitoring dashboard for Snowpipe Streaming pipeline  
**Expires:** 2025-12-25

