#!/bin/bash

set -e

test -d $PGDATA || ./init.sh

exec "$@"
