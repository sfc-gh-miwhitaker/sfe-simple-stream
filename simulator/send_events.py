#!/usr/bin/env python3
"""
Event Simulator - Snowpipe Streaming SDK
Author: SE Community
Purpose: Stream sample RFID badge events using Snowpipe Streaming API
Expires: 2025-12-24
"""

import argparse
import json
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Any
import random

# Snowflake Ingest SDK imports
from snowflake.ingest import SimpleIngestManager
from snowflake.ingest.utils.uris import DEFAULT_SCHEME
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend


def load_config() -> Dict[str, Any]:
    """Load configuration from .secrets/config.json"""
    config_path = Path(__file__).parent.parent / ".secrets" / "config.json"
    
    if not config_path.exists():
        print(f"ERROR: Configuration file not found: {config_path}")
        print("Run ./tools/02_setup_and_test.sh to generate configuration")
        sys.exit(1)
    
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    return config


def load_private_key(key_path: Path) -> bytes:
    """Load and parse private key from file"""
    if not key_path.exists():
        print(f"ERROR: Private key not found: {key_path}")
        print("Run ./tools/02_setup_and_test.sh to generate keys")
        sys.exit(1)
    
    with open(key_path, 'rb') as f:
        private_key_data = f.read()
    
    # Parse the private key
    private_key = serialization.load_pem_private_key(
        private_key_data,
        password=None,
        backend=default_backend()
    )
    
    # Convert to DER format for SDK
    private_key_der = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )
    
    return private_key_der


def generate_sample_events(count: int) -> list:
    """Generate sample RFID badge scan events"""
    
    # Sample data pools
    badge_ids = [f"BADGE-{str(i).zfill(4)}" for i in range(1, 51)]
    user_ids = ["USR-001", "USR-002", "USR-003", "USR-004", "USR-005"]
    zone_ids = ["ZONE-LOBBY-1", "ZONE-OFFICE-201", "ZONE-LAB-301", "ZONE-EXIT-1"]
    directions = ["entry", "exit"]
    
    events = []
    base_time = datetime.utcnow()
    
    for i in range(count):
        event = {
            "badge_id": random.choice(badge_ids),
            "user_id": random.choice(user_ids),
            "zone_id": random.choice(zone_ids),
            "timestamp": (base_time - timedelta(seconds=i*5)).isoformat(),
            "signal_strength": random.randint(-85, -30),
            "direction": random.choice(directions)
        }
        events.append(event)
    
    return events


def stream_events(config: Dict[str, Any], events: list) -> bool:
    """Stream events using Snowpipe Streaming API"""
    
    print(f"📡 Initializing Snowpipe Streaming SDK...")
    
    # Load private key
    key_path = Path(__file__).parent.parent / ".secrets" / config["private_key_path"]
    private_key_der = load_private_key(key_path)
    
    # Initialize Ingest Manager
    try:
        ingest_manager = SimpleIngestManager(
            account=config["account"],
            host=f"{config['account']}.snowflakecomputing.com",
            user=config["user"],
            pipe=f"{config['database']}.{config['schema']}.{config['pipe_name']}",
            private_key=private_key_der
        )
        print(f"✓ Connected to Snowflake account: {config['account']}")
        print(f"✓ Target pipe: {config['database']}.{config['schema']}.{config['pipe_name']}")
        print()
    except Exception as e:
        print(f"ERROR: Failed to initialize Ingest Manager")
        print(f"Details: {e}")
        return False
    
    # Prepare data for ingestion
    print(f"📤 Streaming {len(events)} events...")
    
    # Format events as newline-delimited JSON
    staged_files = []
    file_content = "\n".join([json.dumps(event) for event in events])
    
    # Create temporary file name
    file_name = f"simulator_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json"
    
    try:
        # Ingest data
        response = ingest_manager.ingest_files(
            files=[file_name],
            data=file_content
        )
        
        if response and response.get('responseCode') == 'SUCCESS':
            print(f"✓ Successfully sent {len(events)} events")
            print(f"✓ File: {file_name}")
            print()
            print("=" * 70)
            print("✅ SUCCESS - All events delivered to Snowflake")
            print("=" * 70)
            return True
        else:
            print(f"ERROR: Ingestion failed")
            print(f"Response: {response}")
            return False
            
    except Exception as e:
        print(f"ERROR: Failed to stream events")
        print(f"Details: {e}")
        return False


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Stream sample RFID badge events to Snowflake"
    )
    parser.add_argument(
        "--count",
        type=int,
        help="Number of events to generate (overrides config.json)"
    )
    args = parser.parse_args()
    
    # Load configuration
    print("=" * 70)
    print("Simple Stream - Event Simulator")
    print("=" * 70)
    print()
    
    config = load_config()
    print(f"✓ Configuration loaded")
    print(f"  Account: {config['account']}")
    print(f"  User: {config['user']}")
    print(f"  Database: {config['database']}")
    print(f"  Schema: {config['schema']}")
    print()
    
    # Determine event count
    event_count = args.count if args.count else config.get("sample_events", 10)
    
    # Generate sample events
    print(f"🔧 Generating {event_count} sample events...")
    events = generate_sample_events(event_count)
    print(f"✓ Generated {len(events)} RFID badge scan events")
    print()
    
    # Stream events
    success = stream_events(config, events)
    
    if success:
        print()
        print("Next steps:")
        print("  1. Verify data in Snowsight:")
        print(f"     SELECT COUNT(*) FROM {config['database']}.{config['schema']}.RAW_BADGE_EVENTS;")
        print()
        print("  2. Check monitoring views:")
        print(f"     SELECT * FROM {config['database']}.{config['schema']}.V_INGESTION_HEALTH;")
        print()
        sys.exit(0)
    else:
        print()
        print("Troubleshooting:")
        print("  1. Verify authentication: Check that public key is registered in Snowflake")
        print("  2. Verify permissions: User needs INSERT privilege on target table")
        print("  3. Check network: Ensure HTTPS access to *.snowflakecomputing.com")
        print()
        sys.exit(1)


if __name__ == "__main__":
    main()

