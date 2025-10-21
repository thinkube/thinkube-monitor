# Thinkube Monitor

Curated collection of monitoring dashboards for the Thinkube platform, optimized for single-cluster Kubernetes deployments.

## Overview

This repository contains Perses dashboards adapted from the [Perses Community Dashboards](https://github.com/perses/community-dashboards) project and custom dashboards for Thinkube-specific services.

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

### Applications (2 dashboards)
- **NGINX Ingress Controller**: Ingress traffic and performance
- **Custom Applications**: (placeholder for additional apps)

### GPU Monitoring (1 dashboard)
- **NVIDIA DCGM**: GPU utilization, temperature, power

## Modifications from Upstream

All dashboards in this collection have been modified for single-cluster deployments:

1. **Removed cluster variable requirement** - Dashboards work without the `cluster` label
2. **Simplified queries** - Removed `cluster="$cluster"` filters
3. **Thinkube-specific customizations** - Adapted for Thinkube service names and labels

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
```

## Usage with Thinkube

These dashboards are automatically deployed when you install Prometheus Operator and Perses using the Thinkube playbooks:

```bash
cd ~/thinkube
./scripts/tk_ansible ansible/40_thinkube/optional/prometheus/00_install.yaml
```

The deployment playbook clones this repository and imports all dashboards using `percli`.

## Dashboard Sources

- **Kubernetes, Node Exporter, Prometheus, AlertManager**: Modified from [perses/community-dashboards](https://github.com/perses/community-dashboards)
- **NGINX Ingress**: Migrated from [Grafana Dashboard 9614](https://grafana.com/grafana/dashboards/9614)
- **NVIDIA DCGM**: Migrated from [Grafana Dashboard 12239](https://grafana.com/grafana/dashboards/12239)

## Contributing

To add or modify dashboards:

1. Edit dashboard YAML files in `dashboards/perses/`
2. Test with `percli apply -f <dashboard.yaml>`
3. Commit changes
4. Push to repository

## License

- Community dashboards: Apache-2.0 (from upstream Perses project)
- Thinkube modifications: Apache-2.0
- Grafana migrations: Check original dashboard licenses

## Maintenance

This collection is maintained as part of the Thinkube project. When the upstream Perses community dashboards are updated, review and selectively merge improvements while maintaining single-cluster compatibility.
