# Postgres-XL Docker

Postgres-XL Docker is a Docker image source for
[Postgres-XL](http://www.postgres-xl.org/), the scalable open-source
PostgreSQL-based database cluster. The images are based on CentOS.

The images allow for arbitrary database cluster topologies, allowing GTM,
GTM Proxy, Coordinator, and Datanode nodes to be created and added as desired.
Each service runs in its own container, communicating over a backend network.
Coordinator nodes also connect to a frontend network.

Previously, Postgres-XL Docker used pgxc_ctl for initialisation and control,
running SSH servers as well as database services. This has now been completely
redesigned to run database services directly without SSH, initialising using
included helper scripts, and allowing full flexibility with regard to cluster
topologies.

The pgxc_ctl binary continues to be compiled and provided in the image in case
people find it useful, but this might change in the future, since the up-to-date
recommended Postgres-XL Docker workflow is to *not* use it.

TYPE        | REPO
------------|---------------------------------------------------------
GTM         | <https://hub.docker.com/r/tiredpixel/postgres-xl-gtm/>
GTM Proxy   | <https://hub.docker.com/r/tiredpixel/postgres-xl-proxy/>
Coordinator | <https://hub.docker.com/r/tiredpixel/postgres-xl-coord/>
Datanode    | <https://hub.docker.com/r/tiredpixel/postgres-xl-data/>


## Usage

Instructions are for running on Docker using Docker Compose. It should be
possible to boot an entire Postgres-XL cluster using these instructions. For
running on Docker Swarm, you'll likely have to make minor tweaks. Please wave if
something isn't clear or you have questions when doing this.

Note that the `pg_hba.conf` written is wide-open for any user on the backend
network; if you use this method, be sure that you trust all users on that
network, and isolate client connections using a frontend network. Alternatively,
you might like to configure `ident` or `md5`, edit `pg_hba.conf` yourself, or
not use the provided `init.sh` helper scripts.

These instructions, along with the provided `docker-compose.yml` file, create:

- 1 GTM          (master) (`gtm_1`)
- 2 GTM Proxies           (`proxy_1`, `proxy_2`)
- 2 Coordinators (master) (`coord_1`, `coord_2`)
- 2 Datanodes    (master) (`data_1`,  `data_2`)

```txt
                                  ------------
                                  |  gtm_1   |
                                  ------------
                                /             \
                              /                 \
                            /                     \
                          /                         \
              ------------                           ------------
              | proxy_1  |                           | proxy_2  |
              ------------                           ------------
               |          \                         /          |
               |        ------------        ------------       |
               |        | coord_1  |        | coord_2  |       |
               |        ------------        ------------       |
               |       /             \    /             \      |
               |     /                 \/                 \    |
         ------------      ------------/\------------      ------------
         |  data_1  |     /                          \     |  data_2  |
         ------------ ----                            ---- ------------
```

Other topologies are possible; you likely only need to edit
`docker-compose.yml`, potentially setting additional environment variables, and adjust the initialisation steps below.


## Build

Create a `.env` file from exampled `.env.example`.

Edit `docker-compose.yml` to reflect the desired topology.

Build services by bringing them up; at the end of the build, services will shut
down with a failure because of not yet being initialised:

```sh
docker-compose up
```

This will create backend (`postgres-a`) and frontend (`postgres-b`) networks.
Extract the network address of the backend network, and add it to `.env` as
`PG_NET_CLUSTER_A`, using the helper script:

```sh
bin/get-PG_NET_CLUSTER_A.sh
```


## Initialisation

Initialise each of the nodes using the supplied helper scripts:

```sh
for node in gtm_1 proxy_1 proxy_2 coord_1 coord_2 data_1 data_2
do
docker-compose run --rm $node ./init.sh
done
```

As part of the initialisation, `pg_hba.conf` rules are set to allow all traffic
on the backend network (see warning above, and ensure that it is adequently
protected or that you use an alternative).

Start the services, which should now boot and stay running:

```sh
docker-compose up
```


## Clustering

Prepare a clustering query, able to be executed on each node. Simplest is to use
the same query for each node, open `psql` for each, and paste it into each. If
you do this rather than crafting each line separately, expect some lines to
error.

On coordinators and datanodes:

```sql
ALTER NODE data_1 WITH (TYPE = 'datanode');
ALTER NODE data_2 WITH (TYPE = 'datanode');
CREATE NODE coord_1 WITH (TYPE = 'coordinator', HOST = 'coord_1', PORT = 5432);
CREATE NODE coord_2 WITH (TYPE = 'coordinator', HOST = 'coord_2', PORT = 5432);
CREATE NODE data_1  WITH (TYPE = 'datanode',    HOST = 'data_1',  PORT = 5432);
CREATE NODE data_2  WITH (TYPE = 'datanode',    HOST = 'data_2',  PORT = 5432);
SELECT pgxc_pool_reload();
```

The `ALTER` lines fix the datanodes to have the correct types within the
cluster. The `CREATE` lines specify the cluster topology, but the line for the
localhost will fail. The `pgxc_pool_reload()` reloads the configuration.

Optionally, set preferred nodes. This could be a good idea if you've constrained
nodes to run on specific hosts. For example, if you run `coord_1` and `data_1`
on the same physical host, you might like to run this to ensure cross-network
traffic is minimised.

On `coord_1`:

```sql
ALTER NODE data_1 WITH (PRIMARY, PREFERRED);
SELECT pgxc_pool_reload();
```

On `coord_2`:
```sql
ALTER NODE data_2 WITH (PRIMARY, PREFERRED);
SELECT pgxc_pool_reload();
```

View the topologies on each node:

```sql
SELECT * FROM pgxc_node;
```


## Testing

Test the cluster using the instructions provided in
<http://files.postgres-xl.org/documentation/tutorial-createcluster.html>.

For example, based on those instructions:

On a coordinator:

```sql
CREATE TABLE disttab (col1 int, col2 int, col3 text) DISTRIBUTE BY HASH(col1);
\d+ disttab
CREATE TABLE repltab (col1 int, col2 int) DISTRIBUTE BY REPLICATION;
\d+ repltab
INSERT INTO disttab SELECT generate_series(1, 100), generate_series(101, 200), 'foo';
INSERT INTO repltab SELECT generate_series(1, 100), generate_series(101, 200);
SELECT count(*) FROM disttab;
SELECT xc_node_id, count(*) FROM disttab GROUP BY xc_node_id;
SELECT count(*) FROM repltab;
SELECT xc_node_id, count(*) FROM repltab GROUP BY xc_node_id;
```


## Blessing

May you find peace, and help others to do likewise.


## Licence

Copyright © 2016-2017 [tiredpixel](https://www.tiredpixel.com/).
It is free software, released under the MIT License, and may be redistributed
under the terms specified in `LICENSE.txt`.
