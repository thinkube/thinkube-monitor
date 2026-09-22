# thinkube-monitor

The 25 Perses dashboards that Thinkube imports when Perses is installed.

## What it does

- Holds 25 Perses dashboards as YAML files under `dashboards/perses/`, one
  folder per category: Kubernetes, Node Exporter, Prometheus,
  AlertManager, applications and GPU.
- The dashboards read metrics from the platform's Prometheus.
- 23 dashboards are adapted from
  [perses/community-dashboards](https://github.com/perses/community-dashboards)
  for a single cluster. One (NGINX Ingress Controller) is written for
  Thinkube. One (NVIDIA DCGM) is migrated from Grafana.
- `source-grafana/` keeps the original Grafana JSON of the NGINX Ingress
  and NVIDIA DCGM dashboards.
- `scripts/remove-cluster-variable.sh` removes the `cluster` variable from
  the dashboards in a folder.

## How it reaches a user

It is data read by the Perses optional component. When Perses is installed
from the Optional Components page in thinkube-control, the playbook
`ansible/40_thinkube/optional/perses/14_import_dashboards_percli.yaml` in
[thinkube](https://github.com/thinkube/thinkube) clones this repository
(branch `main`) and imports every dashboard folder with `percli apply`.
Each folder becomes a Perses project of the same name, with a Prometheus
datasource. The repository is not installed on its own.

## Dashboard Categories

### Kubernetes Monitoring (18 dashboards)
- **Cluster Resources**: CPU, memory, network usage across the cluster
- **Namespace Resources**: Per-namespace resource consumption
- **Node Resources**: Individual node metrics
- **Pod Resources**: Pod-level resource tracking
- **Workload Resources**: Deployment, StatefulSet, DaemonSet metrics
- **Networking**: Network traffic and connectivity
- **Persistent Volumes**: Storage metrics
- **API Server**: Kubernetes API performance
- **Controller Manager**: Controller metrics
- **Scheduler**: Scheduler performance
- **Kubelet**: Kubelet metrics
- **Proxy**: kube-proxy metrics

### Node Exporter (2 dashboards)
- **Cluster USE Method**: Cluster-wide utilization, saturation, errors
- **Node Metrics**: Per-node system metrics

### Prometheus (2 dashboards)
- **Prometheus Overview**: Prometheus server metrics
- **Remote Write**: Remote write performance (if configured)

### AlertManager (1 dashboard)
- **AlertManager Overview**: Alert routing and notification metrics

### Applications (1 dashboard)
- **NGINX Ingress Controller**: Custom dashboard with request rates, errors, connections, latency, bandwidth and configuration reloads

### GPU Monitoring (1 dashboard)
- **NVIDIA DCGM**: GPU temperature, power, SM clocks, utilization, framebuffer memory and Tensor Core utilization (8 panels)

## Modifications from Upstream

The dashboards taken from upstream are changed for single-cluster
deployments:

1. **Removed cluster variable** - no dashboard defines the `cluster`
   variable.
2. **Simplified queries** - the `cluster="$cluster"` filters are removed
   from the queries. Five Kubernetes dashboards (API Server, Controller
   Manager, Kubelet, Proxy, Scheduler) still carry `cluster=~"$cluster"`
   in their queries.

## Directory Structure

```
dashboards/
└── perses/
    ├── kubernetes/          # Kubernetes cluster dashboards
    ├── node-exporter/       # System metrics dashboards
    ├── prometheus/          # Prometheus server dashboards
    ├── alertmanager/        # AlertManager dashboards
    ├── applications/        # Application-specific dashboards
    └── gpu/                 # GPU monitoring dashboards
scripts/                     # remove-cluster-variable.sh
source-grafana/              # Grafana JSON the NGINX and DCGM dashboards come from
```

## Dashboard Sources

- **Kubernetes, Node Exporter, Prometheus, AlertManager**: Modified from [perses/community-dashboards](https://github.com/perses/community-dashboards)
- **NGINX Ingress**: Custom dashboard created for Thinkube (based on NGINX Ingress Controller metrics)
- **NVIDIA DCGM**: Migrated from [Grafana Dashboard 12239](https://grafana.com/grafana/dashboards/12239) (source: [NVIDIA dcgm-exporter](https://github.com/NVIDIA/dcgm-exporter/blob/main/grafana/dcgm-exporter-dashboard.json))

[NOTICE](NOTICE) records where each dashboard came from and what was
changed.

## Working on it

To add or modify dashboards:

1. Edit dashboard YAML files in `dashboards/perses/`
2. Test with `percli apply -f <dashboard.yaml>` against a Perses server
3. Commit changes
4. Push to repository

A new category folder is imported only after it is added to
`dashboard_categories` in `14_import_dashboards_percli.yaml`.

### Maintenance

When the upstream Perses community dashboards are updated, review and
selectively merge improvements while keeping single-cluster compatibility.

## License

Apache License 2.0. See [LICENSE](LICENSE).

- Community dashboards: Apache-2.0, Copyright 2024 The Perses Authors
  (from upstream Perses project)
- Thinkube modifications and the NGINX Ingress dashboard: Apache-2.0
- The NVIDIA DCGM dashboard, migrated from Grafana: its upstream copyright
  and licence apply. See [NOTICE](NOTICE).
