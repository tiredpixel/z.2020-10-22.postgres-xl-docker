# Postgres-XL Docker

Postgres-XL Docker is a Docker image source for
[Postgres-XL](http://www.postgres-xl.org/), the PostgreSQL-based database
cluster. The image is based on CentOS, and contains compiled binaries for both
the modified PostgreSQL and pgxc_ctl programs. An OpenSSH Server is run, to
allow pgxc_ctl control.

The image allows for an arbitrary database cluster topology, starting from an
empty configuration and allowing GTM, GTM Proxy, Coordinator, and Datanode
nodes to be added as desired. Each service should run in its own container, with
an additional Control container recommended for running pgxc_ctl and storing
cluster configurations. This only needs to run when actually using the
pgxc_ctl program.


## Usage

Instructions are for running on Docker Swarm using services and overlay
networking. Services are constrained to specific nodes to ensure the availabilty
of mounted volumes. If you're using Flocker or an alternative solution, you
shouldn't need to do this. Also, if you have an alternative solution for
resolution of DNS which survives service container restarts, you might be able
to reduce the number of services defined.

Note that the `pg_hba.conf` written is wide-open for any user on that network;
if you use this method, be sure that you trust all users on that network, and
isolate client connections using another network. Alternatively, you might like
to configure `ident` or `md5`.


### Networking

Create an overlay network:

```bash
pg_cluster=postgresql-1

docker network create \
    -d overlay \
    --internal \
    --opt encrypted \
    $pg_cluster
```


### Control

Create a Control container, with write-access to the SSH volume:

```bash
pg_image=postgres-xl:latest
pg_data=/var/lib/postgres
pg_user=postgres
pg_cluster=postgresql-1
pg_service=ctl-1

docker service create \
    --name $pg_cluster-$pg_service \
    --network $pg_cluster \
    --mount type=volume,src=$pg_cluster-$pg_service,dst=$pg_data \
    --mount type=volume,src=$pg_cluster-ssh,dst=$pg_data/.ssh \
    --constraint node.hostname==$(hostname) \
    $pg_image
```

Initialise the Control container, optionally passing in the network subnet if
you'd like to allow all users on that network to connect to any database (!).
If you're using multiple Swarm nodes and not using Flocker or similar, you'll
either need to replicate the SSH keys yourself, or alternatively generate
multiple keys and add to `.ssh/authorized_keys` yourself as appropriate. The
Control container should be able to reach every node without a password.

```bash
pg_subnet=$(docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' $pg_cluster | tr -d '\n')

docker exec -u $pg_user $(docker ps -q -f name=$pg_cluster-ctl) $pg_data/init.sh $pg_subnet
```


### Cluster

Create GTM, GTM Proxy, Coordinator, and Datanode containers as desired, with
read-only access to the SSH volume. These should be created from the same image
as the Control container, but have independent data volumes.

Create cluster containers, adjusting `pg_service` or running on different Swarm
nodes as desired:

```bash
pg_image=postgres-xl:latest
pg_data=/var/lib/postgres
pg_user=postgres
pg_cluster=postgresql-1

for pg_service in gtm-m-1 coord-m-1 data-m-1 # ...
do
docker service create \
    --name $pg_cluster-$pg_service \
    --network $pg_cluster \
    --mount type=volume,src=$pg_cluster-$pg_service,dst=$pg_data \
    --mount type=volume,src=$pg_cluster-ssh,dst=$pg_data/.ssh:ro \
    --constraint node.hostname==$(hostname) \
    $pg_image
done
```

Check the status of created services, which should boot single instances:

```bash
docker service ls -f name=$pg_cluster
```

```
ID            NAME                    REPLICAS  IMAGE               COMMAND
aaaaaaaaaaa1  postgresql-1-coord-m-1  1/1       postgres-xl:latest  
aaaaaaaaaaa2  postgresql-1-coord-m-2  1/1       postgres-xl:latest  
aaaaaaaaaaa3  postgresql-1-coord-m-3  1/1       postgres-xl:latest  
aaaaaaaaaaa4  postgresql-1-ctl-1      1/1       postgres-xl:latest  
aaaaaaaaaaa5  postgresql-1-data-m-1   1/1       postgres-xl:latest  
aaaaaaaaaaa6  postgresql-1-data-m-2   1/1       postgres-xl:latest  
aaaaaaaaaaa7  postgresql-1-data-m-3   1/1       postgres-xl:latest  
aaaaaaaaaaa8  postgresql-1-gtm-m-1    1/1       postgres-xl:latest  
```


### Initialisation

Initialise the cluster using `pgxc_ctl` commands:

```bash
pg_user=postgres
pg_cluster=postgresql-1

docker exec -it $(docker ps -q -f name=$pg_cluster-ctl) su $pg_user

pgxc_ctl
```

```
add gtm master gtm_m_1 postgresql-1-gtm-m-1 5432 /var/lib/postgres/data/gtm

add coordinator master coord_m_1 postgresql-1-coord-m-1 5432 15432 /var/lib/postgres/data/coord         coordExtraConfig    coordExtraPgHba
add datanode    master data_m_1  postgresql-1-data-m-1  5432 15432 /var/lib/postgres/data/data  none datanodeExtraConfig datanodeExtraPgHba
add coordinator master coord_m_2 postgresql-1-coord-m-2 5432 15432 /var/lib/postgres/data/coord         coordExtraConfig    coordExtraPgHba
add datanode    master data_m_2  postgresql-1-data-m-2  5432 15432 /var/lib/postgres/data/data  none datanodeExtraConfig datanodeExtraPgHba
add coordinator master coord_m_3 postgresql-1-coord-m-3 5432 15432 /var/lib/postgres/data/coord         coordExtraConfig    coordExtraPgHba
add datanode    master data_m_3  postgresql-1-data-m-3  5432 15432 /var/lib/postgres/data/data  none datanodeExtraConfig datanodeExtraPgHba
# ...
```

```
monitor all
```

```
Running: gtm master
Running: coordinator master coord_m_1
Running: coordinator master coord_m_2
Running: coordinator master coord_m_3
Running: datanode master data_m_1
Running: datanode master data_m_2
Running: datanode master data_m_3
```

Restart all containers, to allow Supervisor to control the processes. The type
of node within the cluster is detected automatically.

Verify that all containers have booted services correctly using `monitor all`.

After this point, it is no longer necessary to run a Control container. However,
you might find it useful to keep for monitoring or modifying the cluster.


## Verification

Verify that the cluster is operating as expected by logging into a Coordinator
container:

```bash
pg_user=postgres
pg_cluster=postgresql-1

docker exec -it $(docker ps -q -f name=$pg_cluster-coord-m) su postgres

psql
```

```sql
SELECT * FROM pgxc_node;
```

```
 node_name | node_type | node_port |       node_host        | nodeis_primary | nodeis_preferred |   node_id   
-----------+-----------+-----------+------------------------+----------------+------------------+-------------
 coord_m_1 | C         |      5432 | postgresql-1-coord-m-1 | f              | f                |   767536994
 data_m_1  | D         |      5432 | postgresql-1-data-m-1  | f              | f                |     3954295
 coord_m_2 | C         |      5432 | postgresql-1-coord-m-2 | f              | f                |   752803535
 data_m_2  | D         |      5432 | postgresql-1-data-m-2  | f              | f                |  1425277018
 coord_m_3 | C         |      5432 | postgresql-1-coord-m-3 | f              | f                | -2069407832
 data_m_3  | D         |      5432 | postgresql-1-data-m-3  | f              | f                |   686298590
(6 rows)
```


## Thoughts

- Do Coordinator nodes route to Datanodes constrained to be on the same Swarm
  host, or do they route cross-network expensively?

- How can GTM Proxies be utilised efficiently?

- What is the role of the pooler ports, and does they work properly?

- How can the existing `pg_hba.conf` rules be improved to be more secure, not
  requiring `trust` on the subnet?

- Do Coordinator and Datanode Slaves work correctly?

- How can GTM Slaves and automated failover be achieved?


## Blessing

May you find peace, and help others to do likewise.


## Licence

© 2016 [tiredpixel](https://www.tiredpixel.com/).
It is free software, released under the MIT License, and may be redistributed
under the terms specified in `LICENSE.txt`.
