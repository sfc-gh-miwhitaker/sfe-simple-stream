# Streamlit Dashboard - Real-Time Monitoring

**Time to Deploy:** ~1 minute  
**Prerequisites:** Completed [`04-MONITORING.md`](04-MONITORING.md) (monitoring views created)

---

## Purpose

This guide shows you how to deploy the native Snowflake Streamlit dashboard for real-time pipeline monitoring.

**Key Features:**
- ❄️ **100% Native Snowflake** - Runs entirely within Snowflake (no external hosting)
- 📊 **6 Interactive Views** - Overview, Ingestion, Health, Costs, Tasks, Query Efficiency
- 🔄 **Auto-Refresh** - Dashboard updates every 60 seconds automatically
- 📈 **Interactive Charts** - Plotly visualizations for trend analysis
- 🎯 **Zero Setup** - No credentials or configuration files needed

---

## Quick Deploy (1 Minute)

### Step 1: Deploy Dashboard

Copy/paste into Snowsight worksheet:

```sql
@sql/05_streamlit/deploy_streamlit.sql
```

**What it does:**
1. Creates stage `SFE_STREAMLIT_STAGE` for app files
2. Copies `streamlit_app.py` from Git repository
3. Creates Streamlit app `SFE_SIMPLE_STREAM_MONITOR`
4. Grants access permissions

**Expected output:**
```
✅ STREAMLIT DASHBOARD DEPLOYED
Dashboard Name: SFE_SIMPLE_STREAM_MONITOR
Location: SNOWFLAKE_EXAMPLE.RAW_INGESTION
```

### Step 2: Access Dashboard

1. Open Snowsight
2. Navigate to: **Projects > Streamlit**
3. Click: **SFE_SIMPLE_STREAM_MONITOR**

**Dashboard loads immediately** - no additional configuration needed!

---

## Dashboard Features

### 🎯 Overview Page

**Key Metrics:**
- Total events ingested (last hour)
- Pipeline health status (HEALTHY/WARNING/STALE)
- Credits consumed
- Total rows stored

**Pipeline Health Indicators:**
- **RAW Layer** - Ingestion status
- **STAGING Layer** - Deduplication status  
- **ANALYTICS Layer** - Enrichment status

**Data Freshness Table:**
- Last event timestamps
- Age of data in each layer
- Row counts

---

### 📈 Ingestion Metrics Page

**Charts:**
1. **Events Over Time** - Hourly event volume (last 24 hours)
2. **Entry vs Exit** - Grouped bar chart showing occupancy flow
3. **Signal Quality** - Weak signal percentage trends
4. **Detailed Table** - All hourly metrics

**Metrics Tracked:**
- Event count per hour
- Events per second
- Unique badges and zones
- Average signal strength
- Weak signal percentage
- Net occupancy change

---

### ⏱️ Pipeline Health Page

**Real-Time Status:**
- Layer-by-layer health indicators
- Seconds since last update
- Row count by layer

**Visualizations:**
1. **Latency Chart** - Seconds since update by layer (color-coded by health)
2. **Row Count** - Events processed per layer
3. **Detailed Metrics** - Full health status table

**Health Status Thresholds:**
- **HEALTHY:** < 2 minutes since last update
- **WARNING:** 2-5 minutes since last update
- **STALE:** > 5 minutes since last update

---

### 💰 Cost Tracking Page

**30-Day Cost Analysis:**
- Total credits consumed
- Total GB ingested
- Total rows ingested
- Average credits per GB

**Charts:**
1. **Credits Over Time** - Daily credit consumption (area chart)
2. **Data Volume** - GB ingested per day (bar chart)
3. **Efficiency** - Rows per GB (compression efficiency line chart)
4. **Detailed Breakdown** - Daily cost table

**Use for:**
- Budget tracking
- Cost optimization
- Capacity planning

---

### 🔧 Task Performance Page

**Execution Monitoring:**
- Total executions (24 hours)
- Success rate percentage
- Average execution duration
- Failed execution count

**Visualizations:**
1. **Success Rate by Task** - Bar chart with color gradient
2. **Duration Over Time** - Scatter plot showing execution times
3. **Status Distribution** - Pie chart (Success/Failed/Skipped)
4. **Recent Executions** - Detailed table (failures shown first)

**Alerting:**
- Failed tasks highlighted in red
- Error messages displayed in table

---

### 📊 Query Efficiency Page

**Pruning Analysis:**
- Total queries (24 hours)
- Average scan ratio (lower is better)
- Total GB scanned
- Average prune ratio

**Charts:**
1. **Partition Scan Ratio** - By table (color-coded: EXCELLENT/GOOD/FAIR/POOR)
2. **Query Volume** - Query count by table

**Efficiency Ratings:**
- **EXCELLENT:** < 20% scan ratio
- **GOOD:** 20-50% scan ratio
- **FAIR:** 50-80% scan ratio
- **POOR:** > 80% scan ratio

---

## Architecture

### Native Snowflake Deployment

```
Git Repository (sfe-simple-stream)
  └─ streamlit_app.py
  └─ requirements.txt
          ↓
      COPY FILES
          ↓
  SFE_STREAMLIT_STAGE
          ↓
   CREATE STREAMLIT
          ↓
SFE_SIMPLE_STREAM_MONITOR
(Runs in Snowflake compute)
          ↓
  Monitoring Views
  (V_CHANNEL_STATUS,
   V_INGESTION_METRICS,
   V_END_TO_END_LATENCY,
   ...)
```

**Benefits:**
- ✅ No external hosting required
- ✅ Automatic authentication (Snowflake session)
- ✅ Runs on Snowflake warehouse (usage tracked)
- ✅ Integrated with Snowflake security model
- ✅ Accessible from Snowsight UI

---

## Updating the Dashboard

**To deploy latest version from Git:**

```sql
-- Re-run deployment script (pulls latest from Git)
@sql/05_streamlit/deploy_streamlit.sql
```

**To modify locally and test:**

1. Edit `streamlit_app.py` locally
2. Push changes to Git repository
3. Re-run deployment script

**Changes take effect immediately** (Streamlit apps refresh on code changes)

---

## Customization

### Add Custom Metrics

Edit `streamlit_app.py` to add new queries:

```python
# Add your custom query
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

# Display in dashboard
st.subheader("🏆 Top Badges (Last Hour)")
st.dataframe(custom_df, use_container_width=True)
```

### Change Refresh Interval

Update cache TTL in `streamlit_app.py`:

```python
@st.cache_data(ttl=60)  # Change 60 to desired seconds
def query_snowflake(query: str) -> pd.DataFrame:
    ...
```

### Customize Theme

Dashboard uses Snowflake brand colors by default. To customize, edit queries or add filters.

---

## Troubleshooting

### "Streamlit app not found"

**Cause:** Stage doesn't contain files  
**Fix:**
```sql
-- Verify files in stage
LIST @SFE_STREAMLIT_STAGE;

-- If empty, re-run deployment
@sql/05_streamlit/deploy_streamlit.sql
```

---

### "Permission denied"

**Cause:** Your role doesn't have access  
**Fix:**
```sql
-- Grant access to your role
GRANT USAGE ON STREAMLIT SFE_SIMPLE_STREAM_MONITOR TO ROLE YOUR_ROLE;
```

---

### "Views not found" errors in dashboard

**Cause:** Monitoring views not created  
**Fix:**
```sql
-- Create monitoring views first
@sql/04_monitoring/04_monitoring.sql
```

---

### "No data available" messages

**Cause:** No events ingested yet or tasks not running  
**Fix:**
1. Send test events (see [`03-TESTING.md`](03-TESTING.md))
2. Resume tasks:
   ```sql
   ALTER TASK sfe_raw_to_staging_task RESUME;
   ALTER TASK sfe_staging_to_analytics_task RESUME;
   ```

---

### Dashboard loads slowly

**Cause:** Warehouse may be suspended or undersized  
**Fix:**
```sql
-- Check warehouse status
SHOW WAREHOUSES LIKE 'COMPUTE_WH';

-- Resume if suspended
ALTER WAREHOUSE COMPUTE_WH RESUME;

-- Optionally resize for faster queries
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'SMALL';
```

---

## Cost Considerations

**Dashboard Usage:**
- Runs on `COMPUTE_WH` (specified in deployment script)
- Queries execute every 60 seconds (cached)
- Typical cost: < $0.01/hour for X-SMALL warehouse

**Optimization Tips:**
1. Use X-SMALL warehouse for dashboard queries (sufficient for demo)
2. Auto-suspend warehouse after 60 seconds of inactivity
3. Increase cache TTL to reduce query frequency

```sql
-- Optimize warehouse for dashboard
ALTER WAREHOUSE COMPUTE_WH SET
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;
```

---

## Cleanup

To remove the dashboard:

```sql
-- Drop Streamlit app
DROP STREAMLIT IF EXISTS SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_SIMPLE_STREAM_MONITOR;

-- Drop stage
DROP STAGE IF EXISTS SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_STREAMLIT_STAGE;
```

**Note:** Full cleanup script includes dashboard removal: `sql/99_cleanup/cleanup.sql`

---

## Related Documentation

### Internal Team
- [`04-MONITORING.md`](04-MONITORING.md) - Monitoring views (prerequisite)
- [`03-TESTING.md`](03-TESTING.md) - Send test events
- [`../streamlit/README.md`](../streamlit/README.md) - Dashboard code documentation
- [`../sql/05_streamlit/deploy_streamlit.sql`](../sql/05_streamlit/deploy_streamlit.sql) - Deployment script

### Architecture
- [`../diagrams/data-flow.md`](../diagrams/data-flow.md) - Pipeline architecture

---

## FAQ

**Q: Can I share the dashboard with others?**  
A: Yes, grant USAGE on the Streamlit app:
```sql
GRANT USAGE ON STREAMLIT SFE_SIMPLE_STREAM_MONITOR TO ROLE analyst_role;
```

**Q: Does the dashboard work with my own data?**  
A: Yes, if you point your data to `SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS` table.

**Q: Can I embed the dashboard in a web page?**  
A: Native Snowflake Streamlit apps run in Snowsight. For external embedding, consider Snowflake's embedding capabilities (Enterprise+ edition).

**Q: How do I add authentication/authorization?**  
A: Snowflake Streamlit apps inherit Snowflake's security model. Users need appropriate role grants to access the app.

**Q: Can I run this dashboard externally (outside Snowflake)?**  
A: The code is designed for Snowflake native Streamlit. For external deployment, you'd need to modify the connection logic and use `st.connection("snowflake")` with secrets management.

---

**Ready to monitor?** → Run `@sql/05_streamlit/deploy_streamlit.sql` to deploy!

