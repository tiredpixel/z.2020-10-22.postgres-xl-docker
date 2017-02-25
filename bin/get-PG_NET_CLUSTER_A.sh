#!/bin/sh

PG_NET_CLUSTER_N=${1:-'postgresxldocker_postgres-a'}

PG_NET_CLUSTER_A=$(docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' $PG_NET_CLUSTER_N | tr -d '\n')

echo $PG_NET_CLUSTER_A
