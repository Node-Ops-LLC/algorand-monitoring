# algorand-monitoring

## Monitoring Your Algorand Node

This repository contains all of the files required to run a Dockerized Algorand node monitoring stack. The Algorand node is optional. Some configuration is needed to point to one or more Algorand nodes, including the optional Dockerized "one click" node. The monitoring toolset includes:
- Prometheus container - stores time-series data from the metrics endpoint
- Elasticsearch container - stores telemetry and optional REST API endpoint response data
- Api Caller container - calls REST APIs and stores the response in Elasticsearch
- Grafana container - presents a graphical user interface to monitor node metrics and telemetry
- Algorand container - an optional "one click node" with metrics and telemetry stored by default

The Docker install has been tested on Ubuntu 23.10. It should run on any operating system with Docker installed, including Windows, MacOS, and Linux. The included dashboard presents information about your node host or hosts, including resource utilization and key metrics related to the Algorand blockchain. The materials in this repository are open-source and free to use or modify.

Happy node running!
