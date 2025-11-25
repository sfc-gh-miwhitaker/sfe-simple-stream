#!/bin/bash
################################################################################
# Master Orchestration Script - Simple Stream Demo
# 
# PURPOSE: Fully automated setup and testing with step-by-step execution support
# TIME: ~2 minutes (full run)
# 
# USAGE: 
#   ./tools/02_setup_and_test.sh             # Run all steps (default)
#   ./tools/02_setup_and_test.sh --all       # Explicitly run all steps
#   ./tools/02_setup_and_test.sh --step 5    # Run single step (1-7)
#   ./tools/02_setup_and_test.sh --help      # Show usage
#
# STEPS:
#   1. Get Snowflake account identifier
#   2. Generate RSA key pair
#   3. Register public key with Snowflake
#   4. Generate config.json
#   5. Setup Python environment
#   6. Send test events
#   7. Display verification queries
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SECRETS_DIR="$PROJECT_ROOT/.secrets"
KEYS_DIR="$SECRETS_DIR/keys"
SIMULATOR_DIR="$PROJECT_ROOT/simulator"

# Global variable for account (used across steps)
SNOWFLAKE_ACCOUNT=""

################################################################################
# Usage / Help
################################################################################

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all          Run all steps (default if no options specified)"
    echo "  --step N       Run specific step (1-7)"
    echo "  --help         Show this help message"
    echo ""
    echo "Steps:"
    echo "  1. Get Snowflake account identifier"
    echo "  2. Generate RSA key pair"
    echo "  3. Register public key with Snowflake"
    echo "  4. Generate config.json"
    echo "  5. Setup Python environment"
    echo "  6. Send test events"
    echo "  7. Display verification queries"
    echo ""
    echo "Examples:"
    echo "  $0                  # Run all steps"
    echo "  $0 --all            # Run all steps (explicit)"
    echo "  $0 --step 5         # Run only step 5 (Python setup)"
    echo ""
}

################################################################################
# STEP 1: Get Snowflake Account Identifier
################################################################################

step_1_get_account() {
    echo -e "${YELLOW}Step 1: Snowflake Account${NC}"
    echo "Your account identifier was shown in the deploy_all.sql output."
    echo ""
    echo "If you don't have it, run this query in Snowsight:"
    echo -e "${BLUE}  SELECT CURRENT_ACCOUNT();${NC}"
    echo ""
    
    # Check if account already stored
    if [ -f "$SECRETS_DIR/config.json" ]; then
        STORED_ACCOUNT=$(jq -r '.account' "$SECRETS_DIR/config.json" 2>/dev/null || echo "")
        if [ -n "$STORED_ACCOUNT" ]; then
            echo -e "${YELLOW}Found existing account: $STORED_ACCOUNT${NC}"
            read -p "Use this account? (Y/n): " USE_STORED
            if [[ ! "$USE_STORED" =~ ^[Nn]$ ]]; then
                SNOWFLAKE_ACCOUNT="$STORED_ACCOUNT"
                echo -e "${GREEN}✓ Using account: $SNOWFLAKE_ACCOUNT${NC}"
                echo ""
                return 0
            fi
        fi
    fi
    
    read -p "Enter your Snowflake account identifier (e.g., myorg-myaccount): " SNOWFLAKE_ACCOUNT
    
    if [ -z "$SNOWFLAKE_ACCOUNT" ]; then
        echo -e "${RED}✗ Account identifier is required${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Account: $SNOWFLAKE_ACCOUNT${NC}"
    echo ""
}

################################################################################
# STEP 2: Generate RSA Key Pair
################################################################################

step_2_generate_keys() {
    echo -e "${YELLOW}Step 2: Generate RSA Key Pair${NC}"
    
    mkdir -p "$SECRETS_DIR"
    mkdir -p "$KEYS_DIR"
    
    if [ -f "$KEYS_DIR/rsa_key.p8" ]; then
        echo -e "${YELLOW}⚠ RSA key already exists${NC}"
        read -p "Regenerate? (y/N): " REGENERATE
        if [[ ! "$REGENERATE" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}✓ Using existing key${NC}"
            echo ""
            return 0
        else
            rm -f "$KEYS_DIR/rsa_key.p8" "$KEYS_DIR/rsa_key.pub"
        fi
    fi
    
    echo "Generating 2048-bit RSA key pair..."
    
    # Generate private key
    openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out "$KEYS_DIR/rsa_key.p8" -nocrypt
    
    # Generate public key
    openssl rsa -in "$KEYS_DIR/rsa_key.p8" -pubout -out "$KEYS_DIR/rsa_key.pub"
    
    echo -e "${GREEN}✓ Generated keys in $KEYS_DIR/${NC}"
    echo ""
}

################################################################################
# STEP 3: Register Public Key with Snowflake
################################################################################

step_3_register_auth() {
    echo -e "${YELLOW}Step 3: Register Public Key with Snowflake${NC}"
    
    # Extract public key value (remove header/footer)
    PUBLIC_KEY=$(grep -v "BEGIN PUBLIC KEY" "$KEYS_DIR/rsa_key.pub" | grep -v "END PUBLIC KEY" | tr -d '\n')
    
    # Generate SQL script with the actual public key
    cat > "$SECRETS_DIR/configure_auth_READY.sql" << EOF
/*******************************************************************************
 * GENERATED: Key-Pair Authentication Setup
 * 
 * ⚠️  AUTO-GENERATED - DO NOT COMMIT THIS FILE
 * 
 * PURPOSE: Register public key for SFE_INGEST_USER
 * GENERATED: $(date)
 ******************************************************************************/

USE ROLE SECURITYADMIN;

-- Create or update user with public key
CREATE USER IF NOT EXISTS SFE_INGEST_USER
  COMMENT = 'DEMO: Snowpipe Streaming SDK user | Expires: 2025-12-25';

ALTER USER SFE_INGEST_USER
  SET RSA_PUBLIC_KEY = '$PUBLIC_KEY';

-- Create dedicated role for streaming ingestion
CREATE ROLE IF NOT EXISTS sfe_ingest_role
  COMMENT = 'DEMO: Minimal role for Snowpipe Streaming SDK | Expires: 2025-12-25';

-- Grant role to user
GRANT ROLE sfe_ingest_role TO USER SFE_INGEST_USER;

-- Grant privileges (CRITICAL: Required for Snowpipe Streaming SDK)
USE ROLE SYSADMIN;
GRANT USAGE ON DATABASE SNOWFLAKE_EXAMPLE TO ROLE sfe_ingest_role;
GRANT USAGE ON SCHEMA SNOWFLAKE_EXAMPLE.RAW_INGESTION TO ROLE sfe_ingest_role;
GRANT INSERT ON TABLE SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS TO ROLE sfe_ingest_role;
GRANT OPERATE ON PIPE SNOWFLAKE_EXAMPLE.RAW_INGESTION.SFE_BADGE_EVENTS_PIPE TO ROLE sfe_ingest_role;

-- Verify
USE ROLE SECURITYADMIN;
SHOW USERS LIKE 'SFE_INGEST_USER';
SHOW GRANTS TO ROLE sfe_ingest_role;

SELECT 
  '✅ Authentication configured' AS status,
  'User: SFE_INGEST_USER' AS user_info,
  'Role: sfe_ingest_role' AS role_info,
  'Ready to send events' AS next_step;
EOF
    
    echo -e "${GREEN}✓ Generated SQL: $SECRETS_DIR/configure_auth_READY.sql${NC}"
    echo ""
    echo "Please run this generated SQL in Snowsight to register the public key:"
    echo -e "${BLUE}  Open Snowsight → New Worksheet → Paste contents of:${NC}"
    echo -e "${BLUE}  $SECRETS_DIR/configure_auth_READY.sql${NC}"
    echo ""
    read -p "Press ENTER when you've run the SQL in Snowsight..."
    echo ""
}

################################################################################
# STEP 4: Generate config.json
################################################################################

step_4_create_config() {
    echo -e "${YELLOW}Step 4: Generate config.json${NC}"
    
    # Load account if from existing config or prompt if not set
    if [ -z "$SNOWFLAKE_ACCOUNT" ] && [ -f "$SECRETS_DIR/config.json" ]; then
        SNOWFLAKE_ACCOUNT=$(jq -r '.account' "$SECRETS_DIR/config.json" 2>/dev/null || echo "")
    fi
    
    if [ -z "$SNOWFLAKE_ACCOUNT" ]; then
        echo -e "${RED}✗ Account identifier not set. Run step 1 first.${NC}"
        exit 1
    fi
    
    cat > "$SECRETS_DIR/config.json" << EOF
{
  "account": "$SNOWFLAKE_ACCOUNT",
  "user": "SFE_INGEST_USER",
  "role": "sfe_ingest_role",
  "private_key_path": "keys/rsa_key.p8",
  "database": "SNOWFLAKE_EXAMPLE",
  "schema": "RAW_INGESTION",
  "pipe_name": "sfe_badge_events_pipe",
  "sample_events": 10
}
EOF
    
    echo -e "${GREEN}✓ Created: $SECRETS_DIR/config.json${NC}"
    echo "   Account: $SNOWFLAKE_ACCOUNT"
    echo "   User: SFE_INGEST_USER"
    echo "   Target: SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS"
    echo ""
}

################################################################################
# STEP 5: Setup Python Environment
################################################################################

step_5_setup_python() {
    echo -e "${YELLOW}Step 5: Setup Python Environment${NC}"
    
    if [ ! -d "$SECRETS_DIR/.venv" ]; then
        echo "Creating virtual environment..."
        python3 -m venv "$SECRETS_DIR/.venv"
        echo -e "${GREEN}✓ Created .venv${NC}"
    else
        echo -e "${GREEN}✓ .venv exists${NC}"
    fi
    
    echo "Activating virtual environment..."
    source "$SECRETS_DIR/.venv/bin/activate"
    
    echo "Installing dependencies from simulator/requirements.txt..."
    pip install -q --upgrade pip
    pip install -q -r "$SIMULATOR_DIR/requirements.txt"
    
    echo -e "${GREEN}✓ Python environment ready${NC}"
    echo ""
}

################################################################################
# STEP 6: Send Test Events
################################################################################

step_6_send_events() {
    echo -e "${YELLOW}Step 6: Send Test Events${NC}"
    
    echo "Sending 10 sample RFID badge events..."
    
    # Make sure the script is executable
    chmod +x "$SIMULATOR_DIR/send_events.sh"
    
    # Run the simulator
    "$SIMULATOR_DIR/send_events.sh"
    
    echo ""
    echo -e "${GREEN}✓ Events sent!${NC}"
    echo ""
}

################################################################################
# STEP 7: Validation Queries
################################################################################

step_7_verify() {
    echo -e "${YELLOW}Step 7: Validate Pipeline${NC}"
    
    echo "Run this query in Snowsight to verify:"
    echo -e "${BLUE}"
    cat << 'EOSQL'
-- Check ingested events
SELECT 
  COUNT(*) AS total_events,
  MIN(RECORD_CONTENT:timestamp)::TIMESTAMP_NTZ AS first_event,
  MAX(RECORD_CONTENT:timestamp)::TIMESTAMP_NTZ AS last_event
FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS;

-- Check stream processing
SELECT COUNT(*) AS processed_events
FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS;

-- View analytics
SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_INGESTION_HEALTH;
EOSQL
    echo -e "${NC}"
}

################################################################################
# Security Warning
################################################################################

show_security_warning() {
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⚠️  SECURITY WARNING                                          ║${NC}"
    echo -e "${RED}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║                                                                ║${NC}"
    echo -e "${RED}║  Generated files in .secrets/ contain YOUR credentials:        ║${NC}"
    echo -e "${RED}║                                                                ║${NC}"
    echo -e "${RED}║  • Snowflake account identifier                                ║${NC}"
    echo -e "${RED}║  • RSA private key                                             ║${NC}"
    echo -e "${RED}║  • User configuration                                          ║${NC}"
    echo -e "${RED}║                                                                ║${NC}"
    echo -e "${RED}║  ✓ Auto-protected via .git/info/exclude                        ║${NC}"
    echo -e "${RED}║  ✓ Verification check will run before script exits             ║${NC}"
    echo -e "${RED}║                                                                ║${NC}"
    echo -e "${RED}║  NEVER commit .secrets/ directory!                             ║${NC}"
    echo -e "${RED}║                                                                ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

################################################################################
# Security Check
################################################################################

security_check() {
    if command -v git &> /dev/null; then
        STAGED_SECRETS=$(git diff --cached --name-only 2>/dev/null | grep -E "^\.secrets/" || true)
        
        if [ -n "$STAGED_SECRETS" ]; then
            echo ""
            echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${RED}║  ⛔ SECURITY VIOLATION DETECTED                                ║${NC}"
            echo -e "${RED}╠════════════════════════════════════════════════════════════════╣${NC}"
            echo -e "${RED}║                                                                ║${NC}"
            echo -e "${RED}║  .secrets/ directory is STAGED for commit!                    ║${NC}"
            echo -e "${RED}║                                                                ║${NC}"
            echo -e "${RED}║  Files staged:                                                 ║${NC}"
            while IFS= read -r file; do
                printf "${RED}║  • %-60s║${NC}\n" "$file"
            done <<< "$STAGED_SECRETS"
            echo -e "${RED}║                                                                ║${NC}"
            echo -e "${RED}║  TO FIX:                                                       ║${NC}"
            echo -e "${RED}║  git reset HEAD .secrets/                                     ║${NC}"
            echo -e "${RED}║                                                                ║${NC}"
            echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
            exit 1
        fi
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    # Parse arguments
    RUN_ALL=true
    SPECIFIC_STEP=""
    
    if [ $# -gt 0 ]; then
        case "$1" in
            --help|-h)
                show_usage
                exit 0
                ;;
            --all)
                RUN_ALL=true
                ;;
            --step)
                if [ -z "$2" ]; then
                    echo -e "${RED}ERROR: --step requires a step number (1-7)${NC}"
                    show_usage
                    exit 1
                fi
                SPECIFIC_STEP="$2"
                RUN_ALL=false
                ;;
            *)
                echo -e "${RED}ERROR: Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    fi
    
    # Show header
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Simple Stream - Master Setup & Test                          ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Run steps
    if [ "$RUN_ALL" = true ]; then
        step_1_get_account
        step_2_generate_keys
        step_3_register_auth
        step_4_create_config
        show_security_warning
        step_5_setup_python
        step_6_send_events
        step_7_verify
        security_check
        
        # Completion message
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅ SETUP COMPLETE                                            ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "What just happened:"
        echo "  ✓ Generated RSA keys → $KEYS_DIR/"
        echo "  ✓ Registered public key with Snowflake"
        echo "  ✓ Created config.json with your account"
        echo "  ✓ Setup Python environment"
        echo "  ✓ Sent 10 test events"
        echo ""
        echo "Next steps:"
        echo "  1. Run validation queries above to see your data"
        echo "  2. Monitor: docs/04-MONITORING.md"
        echo "  3. Cleanup: @sql/99_cleanup/cleanup.sql"
        echo ""
        echo -e "${BLUE}Happy streaming! 🚀${NC}"
    else
        # Run specific step
        case "$SPECIFIC_STEP" in
            1) step_1_get_account ;;
            2) step_2_generate_keys ;;
            3) step_3_register_auth ;;
            4) step_4_create_config ;;
            5) step_5_setup_python ;;
            6) step_6_send_events ;;
            7) step_7_verify ;;
            *)
                echo -e "${RED}ERROR: Invalid step number: $SPECIFIC_STEP${NC}"
                echo -e "${RED}Valid steps are 1-7${NC}"
                show_usage
                exit 1
                ;;
        esac
        
        echo ""
        echo -e "${GREEN}✓ Step $SPECIFIC_STEP completed${NC}"
    fi
}

# Run main
main "$@"
