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
  layouts: []          # REQUIRED! Layout definitions (often forgotten)
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

### 3. Variables with PrometheusLabelValuesVariable

Variables populate dropdowns by querying Prometheus labels. **Always use matchers** to filter which metrics to query -- without matchers, you get hundreds of irrelevant results.

```yaml
variables:
  - kind: ListVariable
    spec:
      display:
        name: Instance
        hidden: false
      allowAllValue: false
      allowMultiple: true
      plugin:
        kind: PrometheusLabelValuesVariable
        spec:
          labelName: instance
          matchers:
            - DCGM_FI_DEV_GPU_TEMP  # Filter to specific metrics
      name: instance
```

Variables can reference other variables for cascading filters (e.g., namespace -> controller -> ingress).

### 4. Panel Types and Format Units

- **TimeSeriesChart** - Trends over time, multiple series
- **StatChart** - Current value, single numbers
- **GaugeChart** - Single aggregate value with known max (CPU %, success rate)

**StatChart supported units** (as of v0.52.0): `decimal`, `percent`, `bytes`, `seconds`. Do NOT use `celsius`, `watt`, `fahrenheit`, `hertz` -- they cause validation errors. Use `decimal` and indicate units in the panel name instead.

### 5. SeriesNameFormat

Controls how metric series are labeled in charts:
```yaml
seriesNameFormat: "{{Hostname}} GPU{{gpu}}"
```
Include server/host identifier when monitoring multiple nodes.

### 6. Panel Keys

Panels are keyed by strings (even if they look like numbers). Reference in layouts: `$ref: '#/spec/panels/0'`

## Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|---------|
| "e is not iterable" | Missing `layouts` section | Add layouts with grid items referencing all panels |
| "conflicting values ... and celsius" | Unsupported unit type in StatChart | Use `decimal`, put units in panel name |
| Variable shows hundreds of instances | No matchers on variable | Add matchers to filter to specific metrics |
| Can't distinguish servers | No hostname in seriesNameFormat | Add `{{Hostname}}` to seriesNameFormat |

## Dashboard Development Workflow

### Testing

```bash
export PERSES_URL=https://perses.thinkube.com
percli login --username tkadmin --password <password>
percli apply -f dashboards/perses/applications/my-dashboard.yaml --project applications
```

### Deployment

Dashboards are deployed via Ansible playbook:
```bash
cd ~/thinkube-platform/thinkube
./scripts/tk_ansible ansible/40_thinkube/optional/perses/14_import_dashboards_percli.yaml
```

### Migrating from Grafana

```bash
percli migrate grafana-dashboard.json > perses-dashboard.yaml
```

Manual fixes required after migration: add `layouts` section, fix format units, add matchers to variables, update seriesNameFormat syntax.

## Reference Examples

- **GPU Monitoring**: `dashboards/perses/gpu/nvidia-dcgm-exporter.yaml`
- **Cascading Variables (NGINX)**: `dashboards/perses/applications/nginx-ingress-controller.yaml`

## Additional Resources

- **Perses Documentation:** https://perses.dev/docs/
- **Perses GitHub:** https://github.com/perses/perses
- **PromQL Documentation:** https://prometheus.io/docs/prometheus/latest/querying/basics/
