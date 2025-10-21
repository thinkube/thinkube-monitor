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

    # Remove cluster variable block (from '- kind: ListVariable' with name: cluster to next variable or panels section)
    # Use awk for more reliable processing
    awk '
    BEGIN { in_cluster_var = 0; indent_level = 0 }

    # Detect start of cluster variable
    /kind: ListVariable/ {
        # Check if next few lines contain name: cluster
        getline next_line
        if (next_line ~ /name: cluster/) {
            in_cluster_var = 1
            # Store the indentation level (number of leading spaces before "- kind")
            match($0, /^[[:space:]]*/)
            indent_level = RLENGTH
            next
        } else {
            # Not cluster variable, print both lines
            print
            print next_line
            next
        }
    }

    # Skip lines while in cluster variable block
    in_cluster_var == 1 {
        # Check if we reached next variable or panels section (same or less indentation with "- " or different section)
        if (/^[[:space:]]*-[[:space:]]/ && match($0, /^[[:space:]]*/) <= indent_level) {
            # Reached next variable, stop skipping
            in_cluster_var = 0
            print
        } else if (/^[[:space:]]*panels:/ || /^[[:space:]]*[a-z]+:/) {
            # Reached panels or another top-level section
            in_cluster_var = 0
            print
        }
        # Otherwise skip the line (still in cluster variable block)
        next
    }

    # Print all other lines, removing cluster filters from queries
    {
        # Remove cluster="$cluster" filters from query strings
        gsub(/,cluster="\$cluster"/, "")
        gsub(/cluster="\$cluster",/, "")
        gsub(/cluster="\$cluster"/, "")
        gsub(/\{cluster="\$cluster"\}/, "")
        print
    }
    ' "$dashboard.bak" > "$dashboard"

    # Remove backup if successful
    if [ -f "$dashboard" ]; then
        rm "$dashboard.bak"
        echo "✓ Processed $(basename $dashboard)"
    else
        echo "✗ Failed to process $(basename $dashboard)"
        mv "$dashboard.bak" "$dashboard"
    fi
done

echo "============================================================"
echo "✅ All dashboards processed"
echo "Cluster variable and filters removed from all dashboards"
