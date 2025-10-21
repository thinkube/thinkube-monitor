# CLAUDE.md - Perses Dashboard Development Guide

This file provides guidance to Claude Code when working with Perses dashboards in this repository.

## Project Overview

This repository contains monitoring dashboards for the Thinkube platform using Perses, an open-source dashboard platform designed as a modern alternative to Grafana.

**Perses Version:** v0.52.0 (deployed via Helm chart 0.17.1)
**Dashboard Format:** YAML (Perses native format)
**Deployment Method:** percli (Perses CLI tool)

## Repository Structure

```
thinkube-monitor/
├── dashboards/
│   └── perses/
│       ├── kubernetes/          # 18 dashboards for K8s monitoring
│       ├── node-exporter/       # 2 dashboards for system metrics
│       ├── prometheus/          # 2 dashboards for Prometheus monitoring
│       ├── alertmanager/        # 1 dashboard for alert management
│       ├── applications/        # Custom application dashboards
│       │   └── nginx-ingress-controller.yaml
│       └── gpu/                 # GPU monitoring dashboards
│           └── nvidia-dcgm-exporter.yaml
└── metadata/
    ├── datasources/             # Prometheus datasource definitions by project
    └── projects/                # Project definitions (kubernetes, gpu, etc.)
```

## Critical Perses Concepts

### 1. Required Dashboard Structure

Every Perses dashboard YAML **MUST** have these three sections:

```yaml
kind: Dashboard
metadata:
  name: unique-dashboard-id
  createdAt: 0001-01-01T00:00:00Z
  updatedAt: 0001-01-01T00:00:00Z
  version: 0
spec:
  display:
    name: Human-Readable Dashboard Name
  variables: []        # Variable definitions (optional but common)
  panels: {}           # Panel definitions (required)
  layouts: []          # ⚠️ REQUIRED! Layout definitions (often forgotten)
```

**CRITICAL:** The `layouts` section is **REQUIRED** even though it's at the bottom. Missing this causes the cryptic JavaScript error "e is not iterable" in the browser.

### 2. Layouts Section

Layouts define where panels appear on the dashboard using a grid system:

```yaml
layouts:
  - kind: Grid
    spec:
      display:
        title: Section Title
      items:
        - x: 0          # Horizontal position (left edge)
          "y": 0        # Vertical position (top edge) - MUST be quoted!
          width: 12     # Panel width (24 = full width)
          height: 6     # Panel height
          content:
            $ref: '#/spec/panels/0'  # Reference to panel by key
        - x: 12         # Second column
          "y": 0
          width: 12
          height: 6
          content:
            $ref: '#/spec/panels/1'
```

**Important Notes:**
- Grid is 24 columns wide
- Y-coordinate MUST be quoted (`"y"`) to avoid YAML parsing issues
- Panels stack vertically; increment y by previous panel's height
- Typical two-column layout: left panel (x: 0, width: 12), right panel (x: 12, width: 12)

### 3. Variables with PrometheusLabelValuesVariable

Variables populate dropdowns by querying Prometheus labels:

```yaml
variables:
  - kind: ListVariable
    spec:
      display:
        name: Instance      # Dropdown label
        hidden: false
      allowAllValue: false   # Allow "All" option
      allowMultiple: true    # Allow multi-select
      sort: none            # none | alphabetical-asc | alphabetical-desc
      plugin:
        kind: PrometheusLabelValuesVariable
        spec:
          labelName: instance      # Label to query
          matchers:                # ⚠️ CRITICAL: Filter which metrics to query
            - DCGM_FI_DEV_GPU_TEMP  # Metric name or PromQL expression
      name: instance        # Variable reference name (use in queries as ${instance})
```

**CRITICAL - Matchers:**
- **Without matchers:** Queries ALL instances from ALL metrics (hundreds of results)
- **With matchers:** Queries only instances from specified metrics
- Matchers support full PromQL expressions: `nginx_ingress_controller_requests{namespace="prod"}`

**Cascading Variables:**
Variables can reference other variables for filtering:

```yaml
variables:
  - kind: ListVariable
    spec:
      display:
        name: Namespace
      plugin:
        kind: PrometheusLabelValuesVariable
        spec:
          labelName: namespace
          matchers:
            - nginx_ingress_controller_requests
      name: namespace

  - kind: ListVariable
    spec:
      display:
        name: Controller
      plugin:
        kind: PrometheusLabelValuesVariable
        spec:
          labelName: controller
          matchers:
            - nginx_ingress_controller_requests{namespace=~"${namespace}"}  # Uses previous variable
      name: controller
```

### 4. Panel Types and Format Units

#### TimeSeriesChart
For line/area charts showing metrics over time:

```yaml
panels:
  "0":
    kind: Panel
    spec:
      display:
        name: GPU Temperature
      plugin:
        kind: TimeSeriesChart
        spec: {}  # Usually empty, inherits defaults
      queries:
        - kind: TimeSeriesQuery
          spec:
            plugin:
              kind: PrometheusTimeSeriesQuery
              spec:
                datasource:
                  kind: PrometheusDatasource
                  name: prometheus-datasource
                minStep: ""
                query: DCGM_FI_DEV_GPU_TEMP{instance=~"${instance}", gpu=~"${gpu}"}
                seriesNameFormat: "{{Hostname}} GPU{{gpu}}"
```

#### StatChart
For single number displays (current values):

```yaml
panels:
  "1":
    kind: Panel
    spec:
      display:
        name: GPU Temperature (Current)
      plugin:
        kind: StatChart
        spec:
          calculation: last      # last | mean | sum | min | max | last-number
          format:
            unit: decimal        # ⚠️ See supported units below
            decimalPlaces: 1     # Optional
          valueFontSize: 30      # Optional
      queries:
        - kind: TimeSeriesQuery
          spec:
            plugin:
              kind: PrometheusTimeSeriesQuery
              spec:
                datasource:
                  kind: PrometheusDatasource
                  name: prometheus-datasource
                query: DCGM_FI_DEV_GPU_TEMP{instance=~"${instance}", gpu=~"${gpu}"}
                seriesNameFormat: "{{Hostname}} GPU{{gpu}}"
```

**CRITICAL - Supported Format Units:**

StatChart only supports these units (as of v0.52.0):
- `decimal` - Plain numbers (use for temperature, power, custom metrics)
- `percent` - Percentage values (0-100)
- `bytes` - Byte values with auto-scaling (B, KB, MB, GB)
- `seconds` - Time values with auto-scaling (s, m, h, d)

**DO NOT USE:**
- `celsius` ❌ (causes validation error)
- `watt` ❌ (causes validation error)
- `fahrenheit` ❌
- `hertz` ❌

For temperature in Celsius or power in Watts, use `decimal` and indicate units in the panel name.

#### GaugeChart
For single number with visual bar indicator:

```yaml
panels:
  "2":
    kind: Panel
    spec:
      display:
        name: Success Rate %
      plugin:
        kind: GaugeChart
        spec:
          calculation: last
          max: 100            # Maximum value for gauge scale
          format:
            unit: percent
      queries:
        - kind: TimeSeriesQuery
          spec:
            plugin:
              kind: PrometheusTimeSeriesQuery
              spec:
                query: |
                  sum(rate(nginx_ingress_controller_requests{status!~"[4-5].*"}[5m])) /
                  sum(rate(nginx_ingress_controller_requests[5m])) * 100
```

**When to Use Which:**
- **TimeSeriesChart:** Trends over time, multiple series
- **StatChart:** Current value, individual metrics, multiple values side-by-side
- **GaugeChart:** Single aggregate value with known max (CPU %, memory %, success rate)

### 5. SeriesNameFormat

Controls how metric series are labeled in charts:

```yaml
seriesNameFormat: "{{Hostname}} GPU{{gpu}}"
```

- Uses Go template syntax with metric labels
- Common labels: `{{instance}}`, `{{job}}`, `{{namespace}}`, `{{pod}}`
- Can include static text: `"GPU {{gpu}}"` → "GPU 0", "GPU 1"
- Essential for distinguishing multiple servers: `"{{Hostname}} GPU{{gpu}}"` → "vilanova1 GPU0", "vilanova2 GPU0"

**Best Practice:** Include server/host identifier when monitoring multiple nodes.

### 6. Panel Keys

Panels are keyed by strings (even if they look like numbers):

```yaml
panels:
  "0":      # String key, not integer
    kind: Panel
    ...
  "1":
    kind: Panel
    ...
```

Reference in layouts: `$ref: '#/spec/panels/0'`

## Common Errors and Solutions

### Error: "e is not iterable"

**Symptom:** JavaScript error in browser console, dashboard doesn't load
**Cause:** Missing `layouts` section in dashboard YAML
**Solution:** Add layouts section with grid items referencing all panels

```yaml
layouts:
  - kind: Grid
    spec:
      display:
        title: Metrics
      items:
        - x: 0
          "y": 0
          width: 12
          height: 6
          content:
            $ref: '#/spec/panels/0'
```

### Error: "spec.format.unit: conflicting values ... and celsius"

**Symptom:** Dashboard import fails with validation error about unit type
**Cause:** Using unsupported unit type (celsius, watt, etc.) in StatChart
**Solution:** Change to `decimal` and indicate units in panel name

**Before:**
```yaml
format:
  unit: celsius  # ❌ Not supported
```

**After:**
```yaml
display:
  name: GPU Temperature (°C)  # Units in title
plugin:
  kind: StatChart
  spec:
    format:
      unit: decimal  # ✅ Supported
```

### Error: Variable shows hundreds of instances

**Symptom:** Instance dropdown shows all Prometheus targets (IPs, ports, irrelevant services)
**Cause:** PrometheusLabelValuesVariable without matchers queries all metrics
**Solution:** Add matchers to filter to specific metric(s)

**Before:**
```yaml
plugin:
  kind: PrometheusLabelValuesVariable
  spec:
    labelName: instance
    # No matchers = queries ALL metrics
```

**After:**
```yaml
plugin:
  kind: PrometheusLabelValuesVariable
  spec:
    labelName: instance
    matchers:
      - DCGM_FI_DEV_GPU_TEMP  # Only query GPU metrics
```

### Error: Cannot distinguish metrics from different servers

**Symptom:** Multiple servers selected but chart shows "GPU0" from both without identification
**Cause:** SeriesNameFormat doesn't include server identifier
**Solution:** Add hostname/instance to series name format

**Before:**
```yaml
seriesNameFormat: "GPU{{gpu}}"
# Result: "GPU0", "GPU0" (ambiguous)
```

**After:**
```yaml
seriesNameFormat: "{{Hostname}} GPU{{gpu}}"
# Result: "vilanova1 GPU0", "vilanova2 GPU0" (clear)
```

### Error: Version mismatch warnings in browser

**Symptom:** Console shows "Version 0.51.0-rc.1 does not satisfy requirement ^0.52.0"
**Cause:** Perses server version doesn't match dashboard schema version
**Solution:** Ensure Helm chart version is pinned correctly

Check deployed version:
```bash
kubectl get pods -n perses -o jsonpath='{.items[0].spec.containers[0].image}'
# Should show: persesdev/perses:v0.52.0
```

Fix in deployment playbook:
```yaml
vars:
  perses_chart_version: "0.17.1"  # Chart 0.17.1 = App v0.52.0
```

## Dashboard Development Workflow

### 1. Creating a New Dashboard

Start from a template:

```yaml
kind: Dashboard
metadata:
  name: my-new-dashboard
  createdAt: 0001-01-01T00:00:00Z
  updatedAt: 0001-01-01T00:00:00Z
  version: 0
spec:
  display:
    name: My New Dashboard
  variables: []
  panels: {}
  layouts:
    - kind: Grid
      spec:
        display:
          title: Metrics
        items: []
```

### 2. Testing Dashboard Locally

Use percli to validate before committing:

```bash
# Login to Perses
export PERSES_URL=https://perses.thinkube.com
percli login --username tkadmin --password <password>

# Apply dashboard
percli apply -f dashboards/perses/applications/my-dashboard.yaml --project applications

# View in browser
open https://perses.thinkube.com
```

### 3. Migrating from Grafana

When migrating Grafana dashboards to Perses:

**Automated conversion:**
```bash
percli migrate grafana-dashboard.json > perses-dashboard.yaml
```

**Manual fixes required:**
1. Add `layouts` section (not auto-generated reliably)
2. Fix format units (Grafana supports more units than Perses)
3. Add matchers to variables (Grafana allows unfiltered, Perses needs them)
4. Update seriesNameFormat syntax (different template style)
5. Verify calculations (some Grafana functions differ)

**Common Grafana → Perses mappings:**

| Grafana | Perses Equivalent |
|---------|------------------|
| Singlestat panel | StatChart |
| Graph panel | TimeSeriesChart |
| Gauge panel | GaugeChart |
| Template variable | ListVariable with PrometheusLabelValuesVariable |
| `[[variable]]` | `${variable}` |

### 4. Deployment Process

Dashboards are deployed via Ansible playbook:

```bash
cd ~/thinkube-platform/thinkube
./scripts/tk_ansible ansible/40_thinkube/optional/perses/14_import_dashboards_percli.yaml
```

This playbook:
1. Clones thinkube-monitor repository
2. Logs into Perses with percli
3. Creates projects and datasources
4. Imports all dashboards by category
5. Shows summary of imported dashboards

## Best Practices

### Dashboard Organization

- **Use projects** to group related dashboards (kubernetes, gpu, applications)
- **Name panels clearly** - Include metric type and units in title
- **Use consistent naming** - Follow pattern: "Metric Name (Unit)" or "Metric Name (Current)"

### Variable Design

- **Always use matchers** - Never query all metrics for a label
- **Order variables logically** - Most general first (namespace), most specific last (pod)
- **Use cascading filters** - Reference earlier variables in later matchers
- **Set sensible defaults** - Use `allowAllValue: true` for aggregate views

### Panel Layout

- **Two-column layout** - Standard for related metrics (chart on left, stat on right)
- **Group related panels** - Put time series and current value side-by-side
- **Consistent heights** - Use height: 6 for most panels
- **Full-width for complex** - Use width: 24 for detailed charts

### Query Optimization

- **Use rate() for counters** - Most Prometheus counters need rate()
- **Appropriate range** - [5m] for most dashboards, [1m] for fast-changing metrics
- **Filter in query** - Use label filters: `{namespace="prod", pod=~"app-.*"}`
- **Aggregate wisely** - Use `by` and `without` to control grouping

## Version Compatibility

**Current Configuration:**
- Perses Server: v0.52.0 (deployed via Helm chart 0.17.1)
- percli: v0.52.0
- Dashboard Schema: Perses v0.52.0 format

**Version Consistency Rules:**
1. percli version MUST match Perses server version
2. Dashboard schema version determined by server version
3. Helm chart version != app version (e.g., chart 0.17.1 = app v0.52.0)
4. Check Perses release notes when upgrading for breaking changes

**Finding Version Mapping:**
```bash
# Check Helm chart for app version
helm show chart perses/perses --version 0.17.1 | grep appVersion
# appVersion: v0.52.0
```

## Troubleshooting Guide

### Dashboard doesn't appear after import

1. Check percli output for errors
2. Verify project exists: `percli get projects`
3. Check dashboard is in correct project: `percli get dashboards --project <project>`
4. Look for validation errors in Perses server logs

### No data in panels

1. Verify Prometheus datasource is accessible
2. Test query in Prometheus UI directly
3. Check variable values are being substituted correctly
4. Verify time range includes data
5. Check for label mismatches in query

### Browser shows old dashboard version

1. Hard refresh browser: Ctrl+Shift+R (Linux/Windows) or Cmd+Shift+R (Mac)
2. Clear browser cache for Perses domain
3. Check Kubernetes pod is running updated image
4. Verify dashboard was re-imported successfully

### Variables not loading

1. Check matchers reference existing metrics
2. Verify Prometheus datasource is reachable
3. Test PromQL query in Prometheus UI
4. Check for circular variable dependencies
5. Verify variable names match references in queries

## Reference Examples

### Complete Dashboard Example (GPU Monitoring)

See: `dashboards/perses/gpu/nvidia-dcgm-exporter.yaml`

Key features:
- Variables with matchers for instance and GPU filtering
- Mix of TimeSeriesChart and StatChart panels
- SeriesNameFormat with hostname for multi-server clarity
- Proper layouts with 2-column grid
- Individual GPU metrics (not aggregated)

### Cascading Variables Example (NGINX Ingress)

See: `dashboards/perses/applications/nginx-ingress-controller.yaml`

Key features:
- 4-level variable cascade: namespace → controller_class → controller → ingress
- Each variable filters the next using PromQL matchers
- Comprehensive metrics: requests, errors, latency, connections

## Additional Resources

- **Perses Documentation:** https://perses.dev/docs/
- **Perses GitHub:** https://github.com/perses/perses
- **Perses Examples:** https://github.com/perses/perses/tree/main/dev/data
- **PromQL Documentation:** https://prometheus.io/docs/prometheus/latest/querying/basics/

## AI-Generated Content

This document was created with assistance from Claude Code based on debugging session 2025-10-21, where we:
- Fixed missing layouts causing "e is not iterable" errors
- Resolved version mismatches between percli and Perses server
- Added matchers to variables for proper filtering
- Fixed StatChart format units (decimal vs celsius/watt)
- Improved GPU identification with hostname in series names
- Converted aggregate gauges to individual StatCharts

🤖 Generated with [Claude Code](https://claude.ai/code)
