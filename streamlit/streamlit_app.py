"""
Simple Stream - Real-Time Monitoring Dashboard
Snowflake Native Streamlit App

Author: SE Community
Purpose: Real-time monitoring dashboard for Snowpipe Streaming pipeline
Expires: 2025-12-24

DEMO PROJECT - NOT FOR PRODUCTION USE WITHOUT REVIEW

DEPLOYMENT:
    Run: sql/05_streamlit/deploy_streamlit.sql
    This creates the app natively in Snowflake (no external hosting)
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
from snowflake.snowpark.context import get_active_session

# ============================================================================
# Page Configuration
# ============================================================================

st.set_page_config(
    page_title="Simple Stream Monitor",
    page_icon="❄️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# ============================================================================
# Snowflake Session (Native Streamlit in Snowflake)
# ============================================================================

# Get active Snowflake session (automatically provided by Streamlit in Snowflake)
session = get_active_session()

# ============================================================================
# Helper Functions
# ============================================================================

@st.cache_data(ttl=60)  # Cache for 60 seconds
def query_snowflake(query: str) -> pd.DataFrame:
    """Execute query and return DataFrame with 60-second cache."""
    return session.sql(query).to_pandas()

def format_timedelta(seconds: int) -> str:
    """Format seconds into human-readable timedelta."""
    if seconds < 60:
        return f"{seconds}s"
    elif seconds < 3600:
        return f"{seconds // 60}m {seconds % 60}s"
    else:
        hours = seconds // 3600
        minutes = (seconds % 3600) // 60
        return f"{hours}h {minutes}m"

def get_health_color(status: str) -> str:
    """Return color for health status."""
    colors = {
        'HEALTHY': 'green',
        'WARNING': 'orange',
        'STALE': 'red',
        'SUCCESS': 'green',
        'FAILED': 'red',
        'SKIPPED': 'gray'
    }
    return colors.get(status, 'gray')

# ============================================================================
# Header
# ============================================================================

st.title("❄️ Simple Stream - Real-Time Monitor")
st.caption(f"Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} | Auto-refresh: 60s")

# Add refresh button
col1, col2 = st.columns([6, 1])
with col2:
    if st.button("🔄 Refresh Now"):
        st.cache_data.clear()
        st.rerun()

st.divider()

# ============================================================================
# Sidebar Navigation
# ============================================================================

st.sidebar.title("📊 Dashboard")
page = st.sidebar.radio(
    "Select View",
    [
        "🎯 Overview",
        "📈 Ingestion Metrics",
        "⏱️ Pipeline Health",
        "💰 Cost Tracking",
        "🔧 Task Performance",
        "📊 Query Efficiency"
    ]
)

st.sidebar.divider()
st.sidebar.caption("**Demo Project**")
st.sidebar.caption("Expires: 2025-12-24")
st.sidebar.caption("SE Community")

# ============================================================================
# Page: Overview
# ============================================================================

if page == "🎯 Overview":
    st.header("System Overview")
    
    # Query all key metrics
    try:
        # End-to-end latency
        latency_df = query_snowflake("""
            SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_END_TO_END_LATENCY
        """)
        
        # Channel status
        channel_df = query_snowflake("""
            SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_CHANNEL_STATUS
        """)
        
        # Data freshness
        freshness_df = query_snowflake("""
            SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_DATA_FRESHNESS
        """)
        
        # Top-level KPIs
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            if not channel_df.empty:
                total_rows = channel_df['TOTAL_ROWS_INSERTED'].iloc[0]
                st.metric(
                    "Total Events Ingested",
                    f"{total_rows:,.0f}",
                    delta="Last Hour"
                )
            else:
                st.metric("Total Events Ingested", "N/A")
        
        with col2:
            if not latency_df.empty:
                raw_status = latency_df[latency_df['LAYER'] == 'RAW']['HEALTH_STATUS'].iloc[0]
                seconds = latency_df[latency_df['LAYER'] == 'RAW']['SECONDS_SINCE_UPDATE'].iloc[0]
                st.metric(
                    "Pipeline Status",
                    raw_status,
                    delta=f"{format_timedelta(seconds)} since last event"
                )
            else:
                st.metric("Pipeline Status", "N/A")
        
        with col3:
            if not channel_df.empty:
                credits = channel_df['TOTAL_CREDITS_USED'].iloc[0]
                st.metric(
                    "Credits Used (1h)",
                    f"{credits:.4f}",
                    delta="Streaming ingestion"
                )
            else:
                st.metric("Credits Used (1h)", "N/A")
        
        with col4:
            if not freshness_df.empty:
                total_rows = freshness_df['TOTAL_ROWS'].sum()
                st.metric(
                    "Total Rows Stored",
                    f"{total_rows:,.0f}",
                    delta="All tables"
                )
            else:
                st.metric("Total Rows Stored", "N/A")
        
        st.divider()
        
        # Pipeline Health Status
        st.subheader("🏥 Pipeline Health")
        
        if not latency_df.empty:
            # Create status indicators
            cols = st.columns(3)
            for idx, row in latency_df.iterrows():
                with cols[idx]:
                    status = row['HEALTH_STATUS']
                    color = get_health_color(status)
                    st.markdown(f"**{row['LAYER']} Layer**")
                    st.markdown(f":{color}[●] {status}")
                    st.caption(f"Last update: {format_timedelta(row['SECONDS_SINCE_UPDATE'])} ago")
                    st.caption(f"Rows (1h): {row['ROW_COUNT']:,.0f}")
        else:
            st.info("No pipeline data available. Send events to see metrics.")
        
        st.divider()
        
        # Data Freshness Table
        st.subheader("📊 Data Freshness")
        
        if not freshness_df.empty:
            # Format the dataframe for display
            display_df = freshness_df.copy()
            display_df['LAST_EVENT_TIMESTAMP'] = pd.to_datetime(display_df['LAST_EVENT_TIMESTAMP'])
            display_df['LAST_INGESTION_TIMESTAMP'] = pd.to_datetime(display_df['LAST_INGESTION_TIMESTAMP'])
            display_df['EVENT_AGE'] = display_df['EVENT_AGE_SECONDS'].apply(format_timedelta)
            display_df['INGESTION_AGE'] = display_df['INGESTION_AGE_SECONDS'].apply(format_timedelta)
            
            st.dataframe(
                display_df[['TABLE_NAME', 'LAST_EVENT_TIMESTAMP', 'EVENT_AGE', 'TOTAL_ROWS', 'ROWS_LAST_HOUR']],
                use_container_width=True,
                hide_index=True
            )
        else:
            st.info("No freshness data available.")
    
    except Exception as e:
        st.error(f"Error loading overview: {str(e)}")
        st.info("Ensure views are created by running: sql/04_monitoring/04_monitoring.sql")

# ============================================================================
# Page: Ingestion Metrics
# ============================================================================

elif page == "📈 Ingestion Metrics":
    st.header("Ingestion Metrics")
    
    try:
        metrics_df = query_snowflake("""
            SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_INGESTION_METRICS
            ORDER BY INGESTION_HOUR DESC
            LIMIT 24
        """)
        
        if not metrics_df.empty:
            # Top metrics
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                total_events = metrics_df['EVENT_COUNT'].sum()
                st.metric("Total Events (24h)", f"{total_events:,.0f}")
            
            with col2:
                avg_events_per_hour = metrics_df['EVENT_COUNT'].mean()
                st.metric("Avg Events/Hour", f"{avg_events_per_hour:,.0f}")
            
            with col3:
                unique_badges = metrics_df['UNIQUE_BADGES'].max()
                st.metric("Unique Badges", f"{unique_badges:,.0f}")
            
            with col4:
                avg_signal = metrics_df['AVG_SIGNAL_STRENGTH'].mean()
                st.metric("Avg Signal Strength", f"{avg_signal:.1f} dBm")
            
            st.divider()
            
            # Events over time chart
            st.subheader("📊 Events Over Time (Last 24 Hours)")
            
            fig = px.line(
                metrics_df.sort_values('INGESTION_HOUR'),
                x='INGESTION_HOUR',
                y='EVENT_COUNT',
                title='Hourly Event Volume',
                labels={'EVENT_COUNT': 'Events', 'INGESTION_HOUR': 'Hour'}
            )
            fig.update_traces(line_color='#29B5E8')
            st.plotly_chart(fig, use_container_width=True)
            
            # Entry vs Exit chart
            st.subheader("🚪 Entry vs Exit Events")
            
            fig = go.Figure()
            fig.add_trace(go.Bar(
                x=metrics_df.sort_values('INGESTION_HOUR')['INGESTION_HOUR'],
                y=metrics_df.sort_values('INGESTION_HOUR')['ENTRY_COUNT'],
                name='Entry',
                marker_color='#29B5E8'
            ))
            fig.add_trace(go.Bar(
                x=metrics_df.sort_values('INGESTION_HOUR')['INGESTION_HOUR'],
                y=metrics_df.sort_values('INGESTION_HOUR')['EXIT_COUNT'],
                name='Exit',
                marker_color='#FF6B6B'
            ))
            fig.update_layout(
                title='Entry vs Exit Events by Hour',
                xaxis_title='Hour',
                yaxis_title='Event Count',
                barmode='group'
            )
            st.plotly_chart(fig, use_container_width=True)
            
            # Signal quality distribution
            st.subheader("📡 Signal Quality Distribution")
            
            fig = px.line(
                metrics_df.sort_values('INGESTION_HOUR'),
                x='INGESTION_HOUR',
                y='WEAK_SIGNAL_PCT',
                title='Weak Signal Percentage Over Time',
                labels={'WEAK_SIGNAL_PCT': 'Weak Signal %', 'INGESTION_HOUR': 'Hour'}
            )
            fig.update_traces(line_color='#FF6B6B')
            st.plotly_chart(fig, use_container_width=True)
            
            # Detailed table
            st.subheader("📋 Detailed Metrics Table")
            st.dataframe(
                metrics_df[[
                    'INGESTION_HOUR', 'EVENT_COUNT', 'EVENTS_PER_SECOND',
                    'UNIQUE_BADGES', 'UNIQUE_ZONES', 'AVG_SIGNAL_STRENGTH',
                    'WEAK_SIGNAL_PCT', 'NET_OCCUPANCY_CHANGE'
                ]],
                use_container_width=True,
                hide_index=True
            )
        else:
            st.info("No ingestion metrics available. Send events to see data.")
    
    except Exception as e:
        st.error(f"Error loading ingestion metrics: {str(e)}")

# ============================================================================
# Page: Pipeline Health
# ============================================================================

elif page == "⏱️ Pipeline Health":
    st.header("Pipeline Health & Latency")
    
    try:
        latency_df = query_snowflake("""
            SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_END_TO_END_LATENCY
        """)
        
        if not latency_df.empty:
            # Health status cards
            st.subheader("🏥 Layer Status")
            
            cols = st.columns(3)
            for idx, row in latency_df.iterrows():
                with cols[idx]:
                    status = row['HEALTH_STATUS']
                    color = get_health_color(status)
                    
                    st.markdown(f"### {row['LAYER']} Layer")
                    st.markdown(f":{color}[●] **{status}**")
                    st.metric("Seconds Since Update", f"{row['SECONDS_SINCE_UPDATE']}")
                    st.metric("Row Count (1h)", f"{row['ROW_COUNT']:,.0f}")
                    st.caption(f"Last update: {row['LAST_UPDATE']}")
            
            st.divider()
            
            # Latency chart
            st.subheader("⏱️ Layer Latency")
            
            fig = px.bar(
                latency_df,
                x='LAYER',
                y='SECONDS_SINCE_UPDATE',
                color='HEALTH_STATUS',
                title='Seconds Since Last Update by Layer',
                labels={'SECONDS_SINCE_UPDATE': 'Seconds', 'LAYER': 'Pipeline Layer'},
                color_discrete_map={
                    'HEALTHY': '#00C851',
                    'WARNING': '#FFA900',
                    'STALE': '#FF4444'
                }
            )
            st.plotly_chart(fig, use_container_width=True)
            
            # Row count by layer
            st.subheader("📊 Row Count by Layer (Last Hour)")
            
            fig = px.bar(
                latency_df,
                x='LAYER',
                y='ROW_COUNT',
                title='Events Processed by Layer',
                labels={'ROW_COUNT': 'Row Count', 'LAYER': 'Pipeline Layer'},
                color_discrete_sequence=['#29B5E8']
            )
            st.plotly_chart(fig, use_container_width=True)
            
            # Detailed table
            st.subheader("📋 Detailed Health Metrics")
            st.dataframe(latency_df, use_container_width=True, hide_index=True)
        else:
            st.info("No health data available.")
    
    except Exception as e:
        st.error(f"Error loading pipeline health: {str(e)}")

# ============================================================================
# Page: Cost Tracking
# ============================================================================

elif page == "💰 Cost Tracking":
    st.header("Cost Tracking")
    
    try:
        cost_df = query_snowflake("""
            SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_STREAMING_COSTS
            ORDER BY INGESTION_DATE DESC
            LIMIT 30
        """)
        
        if not cost_df.empty:
            # Top metrics
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                total_credits = cost_df['ACTUAL_CREDITS_USED'].sum()
                st.metric("Total Credits (30d)", f"{total_credits:.4f}")
            
            with col2:
                total_gb = cost_df['GB_INGESTED'].sum()
                st.metric("Total GB Ingested", f"{total_gb:.2f}")
            
            with col3:
                total_rows = cost_df['ROWS_INGESTED'].sum()
                st.metric("Total Rows Ingested", f"{total_rows:,.0f}")
            
            with col4:
                avg_cost_per_gb = total_credits / total_gb if total_gb > 0 else 0
                st.metric("Avg Credits/GB", f"{avg_cost_per_gb:.6f}")
            
            st.divider()
            
            # Credits over time
            st.subheader("💰 Credits Usage Over Time")
            
            fig = px.area(
                cost_df.sort_values('INGESTION_DATE'),
                x='INGESTION_DATE',
                y='ACTUAL_CREDITS_USED',
                title='Daily Credits Consumption',
                labels={'ACTUAL_CREDITS_USED': 'Credits', 'INGESTION_DATE': 'Date'}
            )
            fig.update_traces(line_color='#29B5E8', fillcolor='rgba(41, 181, 232, 0.3)')
            st.plotly_chart(fig, use_container_width=True)
            
            # GB ingested over time
            st.subheader("📊 Data Volume Over Time")
            
            fig = px.bar(
                cost_df.sort_values('INGESTION_DATE'),
                x='INGESTION_DATE',
                y='GB_INGESTED',
                title='Daily Data Volume (GB)',
                labels={'GB_INGESTED': 'GB', 'INGESTION_DATE': 'Date'},
                color_discrete_sequence=['#29B5E8']
            )
            st.plotly_chart(fig, use_container_width=True)
            
            # Efficiency metric
            st.subheader("⚡ Ingestion Efficiency")
            
            fig = px.line(
                cost_df.sort_values('INGESTION_DATE'),
                x='INGESTION_DATE',
                y='ROWS_PER_GB',
                title='Rows per GB (Compression Efficiency)',
                labels={'ROWS_PER_GB': 'Rows/GB', 'INGESTION_DATE': 'Date'}
            )
            fig.update_traces(line_color='#00C851')
            st.plotly_chart(fig, use_container_width=True)
            
            # Detailed table
            st.subheader("📋 Detailed Cost Breakdown")
            st.dataframe(
                cost_df[[
                    'INGESTION_DATE', 'GB_INGESTED', 'ROWS_INGESTED',
                    'ACTUAL_CREDITS_USED', 'ROWS_PER_GB'
                ]],
                use_container_width=True,
                hide_index=True
            )
        else:
            st.info("No cost data available. Data appears after ingestion activity.")
    
    except Exception as e:
        st.error(f"Error loading cost tracking: {str(e)}")

# ============================================================================
# Page: Task Performance
# ============================================================================

elif page == "🔧 Task Performance":
    st.header("Task Execution History")
    
    try:
        task_df = query_snowflake("""
            SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_TASK_EXECUTION_HISTORY
            ORDER BY SCHEDULED_TIME DESC
            LIMIT 50
        """)
        
        if not task_df.empty:
            # Summary metrics
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                total_executions = len(task_df)
                st.metric("Total Executions (24h)", total_executions)
            
            with col2:
                success_rate = (task_df['EXECUTION_STATUS'] == 'SUCCESS').sum() / len(task_df) * 100
                st.metric("Success Rate", f"{success_rate:.1f}%")
            
            with col3:
                avg_duration = task_df['DURATION_SECONDS'].mean()
                st.metric("Avg Duration", f"{avg_duration:.2f}s")
            
            with col4:
                failed_count = (task_df['EXECUTION_STATUS'] == 'FAILED').sum()
                st.metric("Failed Executions", failed_count)
            
            st.divider()
            
            # Success rate by task
            st.subheader("✅ Success Rate by Task")
            
            task_summary = task_df.groupby('TASK_NAME').agg({
                'EXECUTION_STATUS': lambda x: (x == 'SUCCESS').sum() / len(x) * 100,
                'DURATION_SECONDS': 'mean'
            }).reset_index()
            task_summary.columns = ['TASK_NAME', 'SUCCESS_RATE', 'AVG_DURATION']
            
            fig = px.bar(
                task_summary,
                x='TASK_NAME',
                y='SUCCESS_RATE',
                title='Success Rate by Task',
                labels={'SUCCESS_RATE': 'Success Rate (%)', 'TASK_NAME': 'Task'},
                color='SUCCESS_RATE',
                color_continuous_scale=['#FF4444', '#FFA900', '#00C851']
            )
            st.plotly_chart(fig, use_container_width=True)
            
            # Duration over time
            st.subheader("⏱️ Execution Duration Over Time")
            
            fig = px.scatter(
                task_df.sort_values('SCHEDULED_TIME'),
                x='SCHEDULED_TIME',
                y='DURATION_SECONDS',
                color='TASK_NAME',
                title='Task Execution Duration',
                labels={'DURATION_SECONDS': 'Duration (s)', 'SCHEDULED_TIME': 'Time'}
            )
            st.plotly_chart(fig, use_container_width=True)
            
            # Status distribution
            st.subheader("📊 Execution Status Distribution")
            
            status_counts = task_df['EXECUTION_STATUS'].value_counts()
            fig = px.pie(
                values=status_counts.values,
                names=status_counts.index,
                title='Execution Status Distribution',
                color_discrete_map={
                    'SUCCESS': '#00C851',
                    'FAILED': '#FF4444',
                    'SKIPPED': '#CCCCCC'
                }
            )
            st.plotly_chart(fig, use_container_width=True)
            
            # Recent executions table
            st.subheader("📋 Recent Executions")
            
            # Show failures first
            display_df = task_df.copy()
            display_df = display_df.sort_values(['EXECUTION_STATUS', 'SCHEDULED_TIME'], ascending=[True, False])
            
            st.dataframe(
                display_df[[
                    'TASK_NAME', 'SCHEDULED_TIME', 'DURATION_SECONDS',
                    'EXECUTION_STATUS', 'ERROR_MESSAGE'
                ]].head(20),
                use_container_width=True,
                hide_index=True
            )
        else:
            st.info("No task execution history available.")
    
    except Exception as e:
        st.error(f"Error loading task performance: {str(e)}")

# ============================================================================
# Page: Query Efficiency
# ============================================================================

elif page == "📊 Query Efficiency":
    st.header("Query Pruning Efficiency")
    
    try:
        efficiency_df = query_snowflake("""
            SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_PARTITION_EFFICIENCY
        """)
        
        if not efficiency_df.empty:
            # Summary metrics
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                total_queries = efficiency_df['QUERY_COUNT'].sum()
                st.metric("Total Queries (24h)", f"{total_queries:,.0f}")
            
            with col2:
                avg_scan_ratio = efficiency_df['AVG_SCAN_RATIO_PCT'].mean()
                st.metric("Avg Scan Ratio", f"{avg_scan_ratio:.2f}%")
            
            with col3:
                total_gb_scanned = efficiency_df['TOTAL_GB_SCANNED_APPROX'].sum()
                st.metric("Total GB Scanned", f"{total_gb_scanned:.2f}")
            
            with col4:
                avg_prune_ratio = efficiency_df['ROW_PRUNE_RATIO_PCT'].mean()
                st.metric("Avg Prune Ratio", f"{avg_prune_ratio:.2f}%")
            
            st.divider()
            
            # Pruning efficiency by table
            st.subheader("🎯 Pruning Efficiency by Table")
            
            fig = px.bar(
                efficiency_df,
                x='TABLE_NAME',
                y='AVG_SCAN_RATIO_PCT',
                color='PRUNING_EFFICIENCY',
                title='Partition Scan Ratio (Lower is Better)',
                labels={'AVG_SCAN_RATIO_PCT': 'Scan Ratio (%)', 'TABLE_NAME': 'Table'},
                color_discrete_map={
                    'EXCELLENT': '#00C851',
                    'GOOD': '#00C851',
                    'FAIR': '#FFA900',
                    'POOR': '#FF4444'
                }
            )
            st.plotly_chart(fig, use_container_width=True)
            
            # Query count by table
            st.subheader("📊 Query Volume by Table")
            
            fig = px.bar(
                efficiency_df,
                x='TABLE_NAME',
                y='QUERY_COUNT',
                title='Query Count by Table',
                labels={'QUERY_COUNT': 'Queries', 'TABLE_NAME': 'Table'},
                color_discrete_sequence=['#29B5E8']
            )
            st.plotly_chart(fig, use_container_width=True)
            
            # Efficiency indicators
            st.subheader("⚡ Efficiency Indicators")
            
            for _, row in efficiency_df.iterrows():
                efficiency = row['PRUNING_EFFICIENCY']
                color = {
                    'EXCELLENT': 'green',
                    'GOOD': 'green',
                    'FAIR': 'orange',
                    'POOR': 'red'
                }.get(efficiency, 'gray')
                
                with st.expander(f"{row['TABLE_NAME']} - :{color}[{efficiency}]"):
                    col1, col2, col3 = st.columns(3)
                    with col1:
                        st.metric("Queries", f"{row['QUERY_COUNT']:,.0f}")
                    with col2:
                        st.metric("Scan Ratio", f"{row['AVG_SCAN_RATIO_PCT']:.2f}%")
                    with col3:
                        st.metric("Prune Ratio", f"{row['ROW_PRUNE_RATIO_PCT']:.2f}%")
            
            # Detailed table
            st.subheader("📋 Detailed Efficiency Metrics")
            st.dataframe(efficiency_df, use_container_width=True, hide_index=True)
        else:
            st.info("No query efficiency data available. Data appears after query activity.")
    
    except Exception as e:
        st.error(f"Error loading query efficiency: {str(e)}")

# ============================================================================
# Footer
# ============================================================================

st.divider()
st.caption("**Simple Stream Monitor** | SE Community | Demo Project - Expires 2025-12-24")
st.caption("🔄 Dashboard auto-refreshes every 60 seconds | Click 'Refresh Now' for immediate update")

