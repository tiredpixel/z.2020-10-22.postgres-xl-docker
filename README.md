# Postgres-XL Docker

[Postgres-XL Docker](https://github.com/pavouk-0/postgres-xl-docker) is a Docker image source for [Postgres-XL](https://www.postgres-xl.org/), the scalable open-source [PostgreSQL](https://www.postgresql.org/)-based database cluster. The images are based on [Debian](https://www.debian.org/). [Docker images](https://hub.docker.com/r/pavouk0/postgres-xl) are available.

The images allow for arbitrary database cluster topologies, allowing GTM, GTM Proxy, Coordinator, and Datanode nodes to be created and added as desired. Each service runs in its own container, communicating over a backend network. Coordinator nodes also connect to a frontend network.

Previously, Postgres-XL Docker used `pgxc_ctl` for initialisation and control, running SSH servers as well as database services. This has now been completely redesigned to run database services directly without SSH, initialising using included helper scripts, and allowing full flexibility with regard to cluster topologies. The `pgxc_ctl` binary is no longer included in the image, since the recommended Postgres-XL Docker workflow is to *not* use it.

## Usage

Instructions are for running on Docker using Docker Compose. It should be possible to boot an entire Postgres-XL cluster using these instructions. For running on Docker Swarm, you'll likely have to make minor tweaks. Please wave if something isn't clear or you have questions when doing this.

It seems some people think that the way to use Postgres-XL Docker is to build it themselves from the Compose file. This is not the case; the images are published to Docker Hub, and those should normally be used instead. There's no need to compile this locally, unless you actually want to develop Postgres-XL Docker (or possibly Postgres-XL) itself. The supplied `docker-compose.image.yml` provides an example of how to do this; however, note that the `latest` tag is for testing and caching only; if you install a production database using `latest` or no tag at all, then you are doing it wrong, and your production will break at some point in the future. You have been warned. :)

Note that the `pg_hba.conf` written is wide-open for any user on the backend network; if you use this method, be sure that you trust all users on that network, and isolate client connections using a frontend network. Alternatively, you might like to configure `ident` or `md5`, edit `pg_hba.conf` yourself, or not use the provided `init.sh` helper scripts.

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

Other topologies are possible; you likely only need to edit `docker-compose.yml`, potentially setting additional environment variables.

## Build

Clone repository.
Pull source with `git submodule update --init --recursive`.
Edit `docker-compose.yml` to reflect the desired topology.

Build services by bringing them up.

```sh
docker-compose up
```

This will create backend (`db_a`) and frontend (`db_b`) networks.

## Clustering (Automatically)

Prepare an example cluster locally, using the provided example init script. This is not designed for production. Instead, configure by hand using whichever orchestrator you use, or write your own scripts.

```sh
bin/init-eg
```

## Clustering (Swarm; Automatically)

If you're running on Docker Swarm, you can use the provided example `docker-compose.stack.yml` as a starting point, deploying with `docker stack deploy`, along with the init script. Note that the example makes various assumptions, such as that the Swarm node is a manager, that it is tagged with `grp=dbxl`, and that `db_a` has a lower subnet than `db_b` (which might or might not happen automatically; create the networks manually, if you're having trouble).

```sh
bin/init-eg-swarm STACK_NAME
```

Note there are various caveats to using this, which you can read about in detail here:

- https://github.com/pavouk-0/postgres-xl-docker/issues/27
- https://github.com/pavouk-0/postgres-xl-docker/pull/28

## Clustering (Kubernetes; Automatically)

Please keep in mind:

1. So as `docker stack` doesn't support `depends_on` option, it may cause errors until GTM node will be loaded.
2. Scripts below are using `kubectl` to execute commands on the K8s cluster.

```sh
# TO UP
docker stack deploy --orchestrator=kubernetes --namespace=default -c docker-compose.stack.yml pxl_stack
# After you deployed pxl_stack, you need to initialize it (if it didn't do early or you purged PVC)
./bin/init-eg-stack

# TO DOWN
docker stack rm --orchestrator=kubernetes pxl_stack
# Keep in mind that Persistent volumes (PVC) are NOT Docker volumes
# If you want to purge that, you can to remove !!! ALL !!! PVC 👇
kubectl delete pvc --all
# To show all volumes use 👇
kubectl get pv

# TO PORT FORWARD
kubectl port-forward <NAME-OF-POD> 5432:5432
# Also Kubernetes will make port-forwarding. You can find localhost port below 👇
kubectl get service

# TO GET INFO
kubectl get all
# or
docker stack ps --orchestrator=kubernetes pxl_stack

# TO GET LOGS
kubectl describe pod db-data-2-0
kubectl logs db-data-2-0

# TO DEBUG
kubectl exec db-gtm-1-0 -i -t -- bash -il
# Where instead ☝️ db-gtm-1-0 may be used db-coord-1-0, db-coord-2-0, db-data-1-0, db-data-2-0
# If you wanna run psql inside container, I suggest to add /usr/local/lib/postgresql/bin to $PATH var
PATH=/usr/local/lib/postgresql/bin/:${PATH}
```

### Pgpool

Also you can add `pgpool` load balacer to the solution. It needs to make base enter point to database cluster and load balansing between coordinators. It sees cordinators nodes. For that:

1. Download `pgpool.conf` from [gist](https://gist.github.com/urpylka/4f3eeb0ec8d93e9f3ba7b700ad2dafe5).
2. Add these strings below to a `docker-compose` file

    ```docker-compose
      pgpool:
        image: smirart/pgpool:latest
        ports:
          - "5432:5432"
        volumes:
          - ./pgpool.conf:/etc/pgpool/pgpool.conf
        restart: always
        networks:
          - db-b
    ```

You can build [your own pgpool image](https://github.com/urpylka/docker-pgpool), otherwise use the prebuild image `smirart/pgpool:latest`.

> As pgpool alternativity you can use `HAProxy`.

## Clustering (Manually)

Prepare a clustering query, able to be executed on each node. Simplest is to use the same query for each node, open `psql` for each, and paste it into each. If you do this rather than crafting each line separately, expect some lines to error.

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

The `ALTER` lines fix the datanodes to have the correct types within the cluster. The `CREATE` lines specify the cluster topology, but the line for the localhost will fail. The `pgxc_pool_reload()` reloads the configuration.

Optionally, set preferred nodes. This could be a good idea if you've constrained nodes to run on specific hosts. For example, if you run `coord_1` and `data_1` on the same physical host, you might like to run this to ensure cross-network traffic is minimised.

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

We've tried to make this document clear and accessible. If you have any feedback about how we could improve it, or if there's any part of it you'd like to discuss or clarify, we'd love to hear from you. Our contact details are:

Pavouk OÜ | [https://www.pavouk.tech/](https://www.pavouk.tech/) | [en@pavouk.tech](mailto:en@pavouk.tech)

## Licence

Copyright © 2016-2020
[tiredpixel](https://www.tiredpixel.com/),
[Pavouk OÜ](https://www.pavouk.tech/),
and other [contributors](https://github.com/pavouk-0/postgres-xl-docker/graphs/contributors).
It is free software, released under the MIT licence, and may be redistributed under the terms specified in `LICENSE`.
