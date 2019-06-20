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
topologies. The pgxc_ctl binary is no longer included in the image, since the
recommended Postgres-XL Docker workflow is to *not* use it.


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
- 2 Coordinators (master) (`coord_1`, `coord_2`)
- 2 Datanodes    (master) (`data_1`,  `data_2`)

```txt
                                 --------------
                                 |   gtm_1    |
                                 --------------
                                / |          | \
                              /   |          |   \
                            /     |          |     \
                          /       |          |       \
                        /         |          |         \
                      /           |          |           \
                    /             |          |             \
                  /               |          |               \
                /       ------------        ------------      \
               |        | coord_1  |        | coord_2  |       |
               |        ------------        ------------       |
               |       /             \    /             \      |
               |     /                 \/                 \    |
         ------------      ------------/\------------      ------------
         |  data_1  |     /                          \     |  data_2  |
         ------------ ----                            ---- ------------
```

Other topologies are possible; you likely only need to edit
`docker-compose.yml`, potentially setting additional environment variables.


## Build

Edit `docker-compose.yml` to reflect the desired topology.

Build services by bringing them up.

```sh
docker-compose up
```

This will create backend (`db_a`) and frontend (`db_b`) networks.


## Clustering (Automatically)

Prepare an example cluster locally, using the provided example init script.
This is not designed for production. Instead, configure by hand using whichever
orchestrator you use, or write your own scripts.

```sh
bin/init-eg
```


## Clustering (Manually)

Prepare a clustering query, able to be executed on each node. Simplest is to use
the same query for each node, open `psql` for each, and paste it into each. If
you do this rather than crafting each line separately, expect some lines to
error.

On coordinators and datanodes:

```sql
ALTER NODE data_1 WITH (TYPE = 'datanode');
ALTER NODE data_2 WITH (TYPE = 'datanode');
CREATE NODE coord_1 WITH (TYPE = 'coordinator', HOST = 'db_coord_1', PORT = 5432);
CREATE NODE coord_2 WITH (TYPE = 'coordinator', HOST = 'db_coord_2', PORT = 5432);
CREATE NODE data_1  WITH (TYPE = 'datanode',    HOST = 'db_data_1',  PORT = 5432);
CREATE NODE data_2  WITH (TYPE = 'datanode',    HOST = 'db_data_2',  PORT = 5432);
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
<https://www.postgres-xl.org/documentation/tutorial-createcluster.html>.

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


## Contact

We've tried to make this document clear and accessible. If you have any feedback
about how we could improve it, or if there's any part of it you'd like to
discuss or clarify, we'd love to hear from you. Our contact details are:

Pavouk OÜ | <https://www.pavouk.tech/> | <mailto:en@pavouk.tech>


## Licence

Copyright © 2016-2019 [tiredpixel](https://www.tiredpixel.com/),
[Pavouk OÜ](https://www.pavouk.tech/).
It is free software, released under the MIT licence, and may be redistributed
under the terms specified in `LICENSE`.
