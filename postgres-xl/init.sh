#!/bin/bash

set -e

ssh-keygen -f .ssh/id_rsa -N '' -q

cat id_rsa.pub >> .ssh/authorized_keys

pgxc_ctl prepare config empty
