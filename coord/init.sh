#!/bin/sh

initdb \
    -D ${PGDATA} \
    --nodename=${PG_COORD_NODE}
