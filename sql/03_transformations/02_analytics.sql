/*******************************************************************************
 * Analytics Layer
 * Creates: Staging table, dimensions (users, zones, readers), fact table
 * Time: 15 seconds
 ******************************************************************************/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

-- Staging table (transient for cost savings)
USE SCHEMA STAGING_LAYER;

CREATE OR REPLACE TRANSIENT TABLE STG_BADGE_EVENTS (
    badge_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    zone_id VARCHAR(50) NOT NULL,
    reader_id VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMP_NTZ NOT NULL,
    signal_strength NUMBER(5, 2),
    signal_quality VARCHAR(10),
    direction VARCHAR(10),
    ingestion_time TIMESTAMP_NTZ NOT NULL,
    staging_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_stg_badge_events PRIMARY KEY (badge_id, event_timestamp)
)
COMMENT = 'DEMO: Deduplicated staging table'
DATA_RETENTION_TIME_IN_DAYS = 1;

-- Dimension tables
USE SCHEMA ANALYTICS_LAYER;

CREATE OR REPLACE TABLE DIM_USERS (
    user_key NUMBER AUTOINCREMENT PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    user_name VARCHAR(100),
    user_type VARCHAR(20),
    department VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    clearance_level VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    effective_start_date TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP(),
    effective_end_date TIMESTAMP_NTZ,
    is_current BOOLEAN DEFAULT TRUE,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: User dimension (Type 2 SCD)';

CREATE OR REPLACE TABLE DIM_ZONES (
    zone_key NUMBER AUTOINCREMENT PRIMARY KEY,
    zone_id VARCHAR(50) NOT NULL UNIQUE,
    reader_id VARCHAR(50),
    building_name VARCHAR(100) NOT NULL,
    floor_number NUMBER(3),
    zone_name VARCHAR(100) NOT NULL,
    zone_type VARCHAR(50),
    capacity NUMBER,
    requires_clearance VARCHAR(20),
    is_monitored BOOLEAN DEFAULT TRUE,
    is_restricted BOOLEAN DEFAULT FALSE,
    reader_location VARCHAR(100),
    reader_type VARCHAR(50),
    latitude NUMBER(10, 6),
    longitude NUMBER(10, 6),
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: Zone dimension';

CREATE OR REPLACE TABLE DIM_READERS (
    reader_key NUMBER AUTOINCREMENT PRIMARY KEY,
    reader_id VARCHAR(50) NOT NULL UNIQUE,
    reader_name VARCHAR(100),
    reader_type VARCHAR(50),
    manufacturer VARCHAR(50),
    model VARCHAR(50),
    firmware_version VARCHAR(20),
    is_online BOOLEAN DEFAULT TRUE,
    last_heartbeat TIMESTAMP_NTZ,
    created_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'DEMO: Reader dimension';

-- Seed data
INSERT INTO DIM_USERS (user_id, user_name, user_type, department, clearance_level, is_active, is_current)
VALUES
    ('USR-001', 'John Smith', 'EMPLOYEE', 'Engineering', 'CONFIDENTIAL', TRUE, TRUE),
    ('USR-002', 'Jane Doe', 'EMPLOYEE', 'HR', 'PUBLIC', TRUE, TRUE),
    ('USR-003', 'Bob Johnson', 'CONTRACTOR', 'IT Support', 'PUBLIC', TRUE, TRUE),
    ('USR-004', 'Alice Williams', 'EMPLOYEE', 'Security', 'SECRET', TRUE, TRUE),
    ('USR-005', 'Mike Davis', 'VISITOR', 'External', 'PUBLIC', TRUE, TRUE);

INSERT INTO DIM_ZONES (
    zone_id, reader_id, building_name, floor_number, zone_name, zone_type,
    capacity, requires_clearance, is_restricted, reader_location, reader_type
)
VALUES
    ('ZONE-LOBBY-1', 'RDR-101', 'Main Building', 1, 'Main Lobby', 'LOBBY', 100, NULL, FALSE, 'Main Entrance', 'BIDIRECTIONAL'),
    ('ZONE-OFFICE-2A', 'RDR-201', 'Main Building', 2, 'Engineering Office 2A', 'OFFICE', 30, 'CONFIDENTIAL', TRUE, 'Floor 2 East', 'ENTRY'),
    ('ZONE-SERVER-B1', 'RDR-B101', 'Main Building', -1, 'Server Room B1', 'SECURE_AREA', 5, 'SECRET', TRUE, 'Basement Security Door', 'BIDIRECTIONAL'),
    ('ZONE-CONF-3B', 'RDR-301', 'Main Building', 3, 'Conference Room 3B', 'CONFERENCE_ROOM', 20, NULL, FALSE, 'Floor 3 West', 'ENTRY'),
    ('ZONE-PARKING-1', 'RDR-P01', 'Parking Structure', 1, 'Employee Parking Level 1', 'PARKING', 200, NULL, FALSE, 'Garage Entry', 'ENTRY');

-- Fact table (clustered for performance)
CREATE OR REPLACE TABLE FCT_ACCESS_EVENTS (
    event_key NUMBER AUTOINCREMENT PRIMARY KEY,
    user_key NUMBER NOT NULL,
    zone_key NUMBER NOT NULL,
    badge_id VARCHAR(50) NOT NULL,
    reader_id VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMP_NTZ NOT NULL,
    event_date DATE NOT NULL,
    event_hour NUMBER(2) NOT NULL,
    event_day_of_week NUMBER(1) NOT NULL,
    direction VARCHAR(10),
    signal_strength NUMBER(5, 2),
    signal_quality VARCHAR(10),
    is_restricted_access BOOLEAN,
    is_after_hours BOOLEAN,
    is_weekend BOOLEAN,
    ingestion_time TIMESTAMP_NTZ NOT NULL,
    fact_load_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT fk_fct_user FOREIGN KEY (user_key) REFERENCES DIM_USERS(user_key),
    CONSTRAINT fk_fct_zone FOREIGN KEY (zone_key) REFERENCES DIM_ZONES(zone_key)
)
COMMENT = 'DEMO: Access events fact table'
CLUSTER BY (event_date);
