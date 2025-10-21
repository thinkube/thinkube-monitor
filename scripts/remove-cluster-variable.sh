#!/bin/bash
# Copyright 2025 Alejandro Martínez Corriá and the Thinkube contributors
# SPDX-License-Identifier: Apache-2.0

# Script to remove cluster variable requirements from Perses dashboards
# This modifies dashboards to work in single-cluster deployments

set -e

DASHBOARD_DIR="${1:-dashboards/perses}"

echo "Removing cluster variable from dashboards in: $DASHBOARD_DIR"
echo "============================================================"

# Find all YAML files
find "$DASHBOARD_DIR" -name "*.yaml" -type f | while read -r dashboard; do
    echo "Processing: $dashboard"

    # Create backup
    cp "$dashboard" "$dashboard.bak"

    # Remove cluster variable definition (between 'kind: ListVariable' and next variable or 'panels:')
    # This is a complex sed operation, so we'll use python for more reliable processing
    python3 << 'EOF' "$dashboard"
import sys
import yaml

dashboard_file = sys.argv[1]

with open(dashboard_file, 'r') as f:
    dashboard = yaml.safe_load(f)

# Remove cluster variable if it exists
if 'spec' in dashboard and 'variables' in dashboard['spec']:
    dashboard['spec']['variables'] = [
        var for var in dashboard['spec']['variables']
        if not (var.get('kind') == 'ListVariable' and var.get('name') == 'cluster')
    ]

# Function to recursively remove cluster filters from queries
def remove_cluster_filter(obj):
    if isinstance(obj, dict):
        # If this is a query string, remove cluster filter
        if 'query' in obj and isinstance(obj['query'], str):
            # Remove {cluster="$cluster"} and cluster="$cluster" from queries
            obj['query'] = obj['query'].replace('{cluster="$cluster"}', '')
            obj['query'] = obj['query'].replace(',cluster="$cluster"', '')
            obj['query'] = obj['query'].replace('cluster="$cluster",', '')
            obj['query'] = obj['query'].replace('cluster="$cluster"', '')
            # Clean up empty braces
            obj['query'] = obj['query'].replace('{}', '')
        # Recurse into nested dictionaries
        for key, value in obj.items():
            obj[key] = remove_cluster_filter(value)
    elif isinstance(obj, list):
        # Recurse into lists
        return [remove_cluster_filter(item) for item in obj]
    return obj

# Remove cluster filters from all queries
dashboard = remove_cluster_filter(dashboard)

# Write back
with open(dashboard_file, 'w') as f:
    yaml.dump(dashboard, f, default_flow_style=False, sort_keys=False)

print(f"✓ Processed {dashboard_file}")
EOF

    # Remove backup if successful
    rm "$dashboard.bak"
done

echo "============================================================"
echo "✅ All dashboards processed"
echo "Cluster variable and filters removed from all dashboards"
