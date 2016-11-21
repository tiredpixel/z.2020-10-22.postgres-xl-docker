#!/bin/bash -l

set -e

pg_subnet=$1


ssh-keygen -f .ssh/id_rsa -N '' -q

cat .ssh/id_rsa.pub >> .ssh/authorized_keys

chmod 600 .ssh/authorized_keys

pgxc_ctl prepare config empty

touch \
    pgxc_ctl/coordExtraConfig \
    pgxc_ctl/coordExtraPgHba \
    pgxc_ctl/datanodeExtraConfig \
    pgxc_ctl/datanodeExtraPgHba

if [ -n "$pg_subnet" ]
then
    cat <<EOF >> pgxc_ctl/pgxc_ctl.conf

coordPgHbaEntries=($pg_subnet)
datanodePgHbaEntries=($pg_subnet)

EOF
fi
