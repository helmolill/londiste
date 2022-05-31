#! /bin/bash

set -e
set -x

pg_ctl -D /londiste/data -l /londiste/log/pg.log start || { cat /londiste/log/pg.log ; exit 1; }

exec "$@"
