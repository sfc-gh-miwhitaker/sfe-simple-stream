# Data Flow - Simple Stream

**Author:** SE Community
**Created:** 2025-12-02
**Status:** Reference Implementation

![Snowflake](https://img.shields.io/badge/Snowflake-29B5E8?style=for-the-badge&logo=snowflake&logoColor=white)

DEMONSTRATION PROJECT - Timeboxed demo; lifecycle enforcement is implemented in `deploy_all.sql`.

**Reference Implementation:** This code demonstrates production-grade architectural patterns and best practices. Review and customize security, networking, and logic for your organization's specific requirements before deployment.

## Overview

This diagram shows how RFID badge event data flows through the Simple Stream pipeline, from external REST API ingestion through transformation layers to analytics-ready fact tables. The pipeline demonstrates Snowpipe Streaming, CDC with Streams & Tasks, and dimensional modeling.

## Diagram

```mermaid
graph TB
    subgraph "External Data Source"
        RFID[RFID Badge System]
        SIM[Event Simulator<br/>send_events_stream.py]
    end

    subgraph "Ingestion Layer - REST API"
        API[Snowpipe Streaming<br/>REST API Endpoint]
    end

    subgraph "RAW_INGESTION Schema"
        PIPE[sfe_badge_events_pipe<br/>JSON->Relational Transform]
        RAW[(RAW_BADGE_EVENTS<br/>Permanent Table<br/>Append-Only)]
        STREAM[sfe_badge_events_stream<br/>CDC Stream]
    end

    subgraph "STAGING_LAYER Schema"
        TASK1[sfe_raw_to_staging_task<br/>Runs: Every 1 min<br/>Trigger: STREAM_HAS_DATA]
        STG[(STG_BADGE_EVENTS<br/>Transient Table<br/>Deduplicated)]
    end

    subgraph "ANALYTICS_LAYER Schema - Master Data"
        DIM_U[(DIM_USERS<br/>SCD Type 2<br/>Seeded Data)]
        DIM_Z[(DIM_ZONES<br/>SCD Type 2<br/>Seeded Data)]
    end

    subgraph "ANALYTICS_LAYER Schema - Facts"
        TASK2[sfe_staging_to_analytics_task<br/>Runs: After TASK1<br/>Joins Dimensions]
        FACT[(FCT_ACCESS_EVENTS<br/>Permanent Table<br/>Clustered by Date)]
    end

    subgraph "Consumption Layer"
        VIEWS[Monitoring Views<br/>V_INGESTION_METRICS<br/>V_END_TO_END_LATENCY<br/>V_STREAMING_COSTS]
        BI[BI Tools / Dashboards]
    end

    %% Flow connections
    RFID -->|HTTPS POST<br/>JSON Events| API
    SIM -->|HTTPS POST<br/>JSON Events| API

    API -->|Streaming Insert| PIPE
    PIPE -->|Server-Side Transform<br/>Extract JSON fields| RAW

    RAW -->|Tracks INSERTs| STREAM

    STREAM -->|When HAS_DATA| TASK1
    TASK1 -->|MERGE<br/>Deduplicate<br/>ON (badge_id, timestamp)| STG

    STG -->|After TASK1<br/>Completes| TASK2
    DIM_U -->|LEFT JOIN<br/>ON user_id| TASK2
    DIM_Z -->|LEFT JOIN<br/>ON zone_id| TASK2
    TASK2 -->|INSERT<br/>Enriched Events| FACT

    FACT --> VIEWS
    VIEWS --> BI

    %% Styling
    classDef source fill:#e1f5ff,stroke:#0288d1,stroke-width:2px
    classDef raw fill:#fff9c4,stroke:#fbc02d,stroke-width:2px
    classDef staging fill:#f0f4c3,stroke:#9e9d24,stroke-width:2px
    classDef analytics fill:#c8e6c9,stroke:#388e3c,stroke-width:2px
    classDef consumption fill:#f8bbd0,stroke:#c2185b,stroke-width:2px

    class RFID,SIM source
    class API,PIPE,RAW,STREAM raw
    class TASK1,STG staging
    class DIM_U,DIM_Z,TASK2,FACT analytics
    class VIEWS,BI consumption
```

## Component Descriptions

### Source Systems

**RFID Badge System**
- **Purpose:** Physical RFID readers tracking badge scans
- **Technology:** Hypothetical external system (not included in demo)
- **Location:** External to Snowflake
- **Data Format:** JSON over HTTPS
- **Frequency:** Real-time (milliseconds latency)

**Event Simulator (send_events_stream.py)**
- **Purpose:** Demo script that mimics RFID system behavior
- **Technology:** Python 3.9+ with Snowpipe Streaming SDK
- **Location:** `.secrets/send_events_stream.py`
- **Dependencies:** PyJWT, cryptography, requests
- **Authentication:** Key-pair JWT

### Ingestion Layer

**Snowpipe Streaming REST API**
- **Endpoint Type:** Snowflake-managed REST endpoint
- **Purpose:** High-throughput, low-latency data ingestion
- **Performance:** Millions of events/second capacity
- **Latency:** < 1 minute to queryable
- **Authentication:** OAuth 2.0 or Key-pair JWT
- **Configuration:** Auto-configured via pipe creation

**sfe_badge_events_pipe**
- **Purpose:** JSON-to-relational transformation at ingestion time
- **Technology:** Snowpipe with inline COPY transformation
- **Transformations Applied:**
  - Extract JSON fields to typed columns
  - Compute signal_quality from signal_strength RSSI
  - Uppercase direction field
  - Add server-side ingestion timestamp
  - Store original JSON in raw_json VARIANT column
- **Error Handling:** Invalid JSON logs to pipe error messages
- **Cost:** Serverless (billed per GB ingested)

### RAW_INGESTION Layer

**RAW_BADGE_EVENTS Table**
- **Purpose:** Immutable landing table (source of truth)
- **Pattern:** Append-only (no updates/deletes)
- **Volume:** ~10,000 events/day (demo scenario)
- **Retention:** 1 day Time Travel (DATA_RETENTION_TIME_IN_DAYS = 1)
- **Optimization:** Natural ingestion order clustering

**sfe_badge_events_stream**
- **Purpose:** Change data capture for incremental processing
- **Type:** Standard stream (tracks all DML, but only INSERTs occur)
- **Offset Management:** Auto-advanced on successful task completion
- **Metadata:** METADATA$ACTION, METADATA$ISUPDATE, METADATA$ROW_ID
- **Consumption:** Read by sfe_raw_to_staging_task

### STAGING_LAYER Layer

**sfe_raw_to_staging_task**
- **Schedule:** SCHEDULE = '1 MINUTE'
- **Trigger:** WHEN SYSTEM$STREAM_HAS_DATA('sfe_badge_events_stream')
- **Warehouse:** COMPUTE_WH (X-SMALL sufficient)
- **Logic:** MERGE statement
  - Deduplication: ON (badge_id, event_timestamp)
  - Action: INSERT only (no updates in this pattern)
- **Error Handling:** Task failure logged to TASK_HISTORY
- **Dependencies:** None (root task)

**STG_BADGE_EVENTS Table**
- **Purpose:** Deduplicated, quality-filtered events
- **Table Type:** Transient (no Fail-safe, reduces storage cost 50%)
- **Retention:** 0 days Time Travel (rebuild from RAW if needed)
- **Quality Filters:**
  - Remove duplicate (badge_id, event_timestamp) pairs
  - Remove events with signal_strength < -90 dBm (too weak)
- **Volume:** ~9,500 events/day (5% duplicates filtered)

### ANALYTICS_LAYER Layer

**DIM_USERS & DIM_ZONES (Dimension Tables)**
- **Load Pattern:** Pre-seeded with sample data in deployment
- **Update Frequency:** Infrequent (weekly or on-demand)
- **Update Method:** Manual MERGE or separate ETL (not automated in this demo)
- **SCD Type 2 Pattern:**
  - effective_from / effective_to date ranges
  - is_current boolean flag for active record
  - Maintains full history of dimensional changes

**sfe_staging_to_analytics_task**
- **Schedule:** Dependent on sfe_raw_to_staging_task (runs after parent completes)
- **Trigger:** After parent task success
- **Warehouse:** COMPUTE_WH (X-SMALL)
- **Logic:** INSERT with LEFT JOINs
  - Join STG_BADGE_EVENTS to DIM_USERS on user_id
  - Join to DIM_ZONES on zone_id
  - Calculate dwell_time_minutes (if applicable)
  - Insert enriched row into fact table
- **Orphan Handling:** NULL dimension FKs allowed (logged in monitoring views)

**FCT_ACCESS_EVENTS Table**
- **Purpose:** Analytics-ready fact table with full dimensional context
- **Table Type:** Permanent (critical analytics data)
- **Retention:** 90 days Time Travel (DATA_RETENTION_TIME_IN_DAYS = 90)
- **Clustering Key:** TO_DATE(event_timestamp)
  - Improves query pruning for date-range filters
  - Low cardinality (~365 values/year)
  - Auto-clustering maintains optimal layout
- **Volume:** ~9,500 events/day
- **Growth:** ~3.5 million events/year

### Consumption Layer

**Monitoring Views (7 views)**
- **V_INGESTION_METRICS:** Events per hour, hourly trends
- **V_END_TO_END_LATENCY:** Time from event_timestamp to processed_time
- **V_STREAMING_COSTS:** Credit consumption estimates
- **V_CHANNEL_STATUS:** Snowpipe Streaming channel health
- **V_TASK_EXECUTION_HISTORY:** Task run success/failure rates
- **V_DATA_QUALITY_METRICS:** Duplicate rates, orphan rates, signal quality distribution
- **V_ACTIVE_BADGES:** Currently active badges in the system

**BI Tools / Dashboards**
- **Purpose:** Business intelligence consumption
- **Technology:** Any Snowflake-connected BI tool (Tableau, Power BI, Looker, etc.)
- **Query Pattern:** Read-only SELECT from FCT_ACCESS_EVENTS and monitoring views

## Data Transformation Details

| Stage | Input Format | Transformation | Output Format | Latency |
|-------|-------------|----------------|---------------|---------|
| **Ingestion** | JSON over HTTPS | Extract fields, type conversion, computed columns | Relational table rows | < 10 seconds |
| **Deduplication** | Raw events | MERGE dedup on (badge_id, timestamp), quality filters | Staging table | ~1 minute |
| **Enrichment** | Staging events | LEFT JOIN dimensions, calculate metrics | Fact table | ~1 minute |
| **Aggregation** | Fact table | GROUP BY, window functions in views | Aggregated metrics | Real-time (query time) |

**Total End-to-End Latency:** < 2 minutes (ingestion -> queryable analytics)

## Data Volume Estimates (Demo Scenario)

| Layer | Daily Volume | Monthly Volume | Annual Volume | Storage (Compressed) |
|-------|--------------|----------------|---------------|---------------------|
| RAW_BADGE_EVENTS | 10,000 | 300,000 | 3.6M | ~100 MB/year |
| STG_BADGE_EVENTS | 9,500 | 285,000 | 3.4M | ~90 MB/year |
| FCT_ACCESS_EVENTS | 9,500 | 285,000 | 3.4M | ~200 MB/year (with dimensions) |

**Note:** Production volumes could be 100-1000x higher

## Error Handling & Data Quality

### Pipe Errors
- **Detection:** `SHOW PIPES` -> `EXECUTION_STATE = 'ERRORS'`
- **Recovery:** Review `COPY_HISTORY`, fix JSON format, restart pipe
- **Monitoring:** V_CHANNEL_STATUS view

### Task Failures
- **Detection:** `TASK_HISTORY` table or V_TASK_EXECUTION_HISTORY view
- **Recovery:** ALTER TASK ... RESUME after fixing root cause
- **Alerting:** (Not implemented in this demo, production would use notifications)

### Data Quality Issues
- **Duplicates:** Automatically deduplicated in MERGE to staging
- **Orphans:** NULL foreign keys in fact table, tracked in V_DATA_QUALITY_METRICS
- **Late Arrivals:** No special handling (append-only, tasks process all new data)

## Performance Optimizations

### Micro-batch Processing
- **Pattern:** Tasks run every 1 minute only when stream has data
- **Benefit:** No unnecessary task executions (cost savings)
- **Trade-off:** 1-minute max latency (vs. real-time)

### Clustering
- **Table:** FCT_ACCESS_EVENTS
- **Key:** TO_DATE(event_timestamp)
- **Impact:** 90%+ reduction in scanned partitions for date-range queries
- **Maintenance:** Automatic clustering enabled (serverless, billed per GB)

### Table Types
- **Transient Staging:** Reduces storage costs by 50% (no Fail-safe)
- **Permanent Facts:** Full recovery capabilities for critical analytics data

## Change History

See Git history for change tracking.

## Related Diagrams
- `data-model.md` - Database schema and relationships
- `network-flow.md` - Network connectivity architecture
- `auth-flow.md` - Authentication and authorization flow
