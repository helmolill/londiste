#! /bin/bash

. ../testlib.sh

v='-q'
v=''
nocheck=1

db_list="recentdb globaldb regiondb archivedb"

kdb_list=`echo $db_list | sed 's/ /,/g'`

do_check() {
  test $nocheck = 1 || ../zcheck.sh
}

title Execute test

# create ticker conf
cat > conf/pgqd.ini <<EOF
[pgqd]
database_list = $kdb_list
ticker_period = 0.2
check_period = 1
syslog = 0
logfile = log/pgqd.log
pidfile = pid/pgqd.pid
EOF

for db in $db_list; do
  cleardb $db
done

clearlogs

set -e

msg "Initialize nodes"
run londiste $v cf/recentq_recentdb.ini create-root recentq_recentdb
run londiste $v cf/globalq_globaldb.ini create-root globalq_globaldb
run londiste $v cf/regionq_regiondb.ini create-root regionq_regiondb
run londiste $v cf/archiveq_archivedb.ini create-root archiveq_archivedb
run londiste $v cf/recentq_globaldb.ini create-leaf recentq_globaldb --provider='dbname=recentdb' --merge='globalq'
run londiste $v cf/recentq_regiondb.ini create-leaf recentq_regiondb --provider='dbname=recentdb' --merge='regionq'
run londiste $v cf/recentq_archivedb.ini create-leaf recentq_archivedb --provider='dbname=recentdb' --merge='archiveq'
run londiste $v cf/globalq_regiondb.ini create-leaf globalq_regiondb --provider='dbname=globaldb' --merge='regionq'
run londiste $v cf/regionq_recentdb.ini create-leaf regionq_recentdb --provider='dbname=regiondb' --merge='recentq'
run londiste $v cf/regionq_archivedb.ini create-leaf regionq_archivedb --provider='dbname=regiondb' --merge='archiveq'

msg "Run ticker"
run pgqd $v -d conf/pgqd.ini
run sleep 2

msg "See topology"
run londiste $v cf/recentq_recentdb.ini status
run londiste $v cf/globalq_globaldb.ini status
run londiste $v cf/regionq_regiondb.ini status

msg "Run londiste daemon for each node"
run londiste $v -d cf/recentq_recentdb.ini worker
run londiste $v -d cf/globalq_globaldb.ini worker
run londiste $v -d cf/regionq_regiondb.ini worker
run londiste $v -d cf/archiveq_archivedb.ini worker
run londiste $v -d cf/recentq_globaldb.ini worker
run londiste $v -d cf/recentq_regiondb.ini worker
run londiste $v -d cf/recentq_archivedb.ini worker
run londiste $v -d cf/globalq_regiondb.ini worker
run londiste $v -d cf/regionq_recentdb.ini worker
run londiste $v -d cf/regionq_archivedb.ini worker

msg "Create tables"
run_sql recentdb "create table recentq_table (id int4 primary key, payload text)"
run_sql globaldb "create table recentq_table (id int4 primary key, payload text)"
run_sql regiondb "create table recentq_table (id int4 primary key, payload text)"
run_sql archivedb "create table recentq_table (id int4 primary key, payload text)"
run_sql globaldb "create table globalq_table (id int4 primary key, payload text)"
run_sql regiondb "create table globalq_table (id int4 primary key, payload text)"
run_sql recentdb "create table globalq_table (id int4 primary key, payload text)"
run_sql archivedb "create table globalq_table (id int4 primary key, payload text)"
run_sql regiondb "create table regionq_table (id int4 primary key, payload text)"
run_sql recentdb "create table regionq_table (id int4 primary key, payload text)"
run_sql archivedb "create table regionq_table (id int4 primary key, payload text)"
run_sql archivedb "create table archiveq_table (id int4 primary key, payload text)"

msg "Alter tables and run londiste execute"
mkdir sql
tables="recentq_table globalq_table regionq_table archiveq_table"
for table in $tables; do
  echo "alter table if exists ${table} add column if not exists test1 text" > sql/${table}.sql
done
run londiste $v cf/recentq_recentdb.ini execute sql/recentq_table.sql
run londiste $v cf/globalq_globaldb.ini execute sql/globalq_table.sql
run londiste $v cf/regionq_regiondb.ini execute sql/regionq_table.sql
run londiste $v cf/archiveq_archivedb.ini execute sql/archiveq_table.sql

run tail -f log/regionq_archivedb.log
