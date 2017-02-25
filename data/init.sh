#!/bin/sh

initdb \
    -D ${PGDATA} \
    --nodename=${PG_DATA_NODE}
