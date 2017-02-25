#!/bin/sh

PG_NET_CLUSTER_N=${PG_NET_CLUSTER_N:-'postgresxldocker_postgres-cluster'}

PG_NET_CLUSTER_A=$(sudo docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' $PG_NET_CLUSTER_N | tr -d '\n')

echo $PG_NET_CLUSTER_A
