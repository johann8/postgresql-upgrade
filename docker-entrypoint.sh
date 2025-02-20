#!/usr/bin/env bash
#set -x

# set vars
: "${PGUSER:=postgres}"
: "${POSTGRES_NEW:=17}"
: "${DB_INIT:=true}"
POSTGRES_OLD=$(cat /pg_old/data/PG_VERSION)

#
RE='^[0-9]+([.][0-9]+)?$'
if ! [[ ${POSTGRES_OLD} =~ ${RE} ]] ; then
   echo "ERROR: version not found in file /pg_old/data/PG_VERSION" >&2; exit 1
else
   echo "Postgres version is: ${POSTGRES_OLD}"
fi

# export vars
export PGBINOLD=/usr/lib/postgresql/${POSTGRES_OLD}/bin
export PGBINNEW=/usr/lib/postgresql/${POSTGRES_NEW}/bin
export PGDATAOLD=/pg_old/data
export PGDATANEW=/pg_new/data
export PGUSER="${PGUSER}"

# 
if [ "$#" -eq 0 -o "${1:0:1}" = '-' ]; then
  set -- pg_upgrade
fi

# run as user "root"
if [ "$(id -u)" = '0' ] ;then
   echo "Found PostgreSQL ${POSTGRES_OLD} (OLD database)"

   # Install POSTGRES_OLD binaries
   echo "Installing binaries required"
   sed -i "s/$/ ${POSTGRES_OLD}/" /etc/apt/sources.list.d/pgdg.list
   apt-get update > /dev/null 2>&1
   apt-get install -y -qq --no-install-recommends \
    postgresql-${POSTGRES_OLD} postgresql-contrib-${POSTGRES_OLD} > /dev/null 2>&1
   echo "PostgreSQL ${POSTGRES_OLD} binaries installed"
  
   # Install POSTGRES_NEW binaries
   sed -i "s/$/ ${POSTGRES_NEW}/" /etc/apt/sources.list.d/pgdg.list
   apt-get install -y -qq --no-install-recommends \
    postgresql-${POSTGRES_NEW} postgresql-contrib-${POSTGRES_NEW} > /dev/null 2>&1
   echo "PostgreSQL ${POSTGRES_NEW} binaries installed"

#   mkdir -p "$PGDATAOLD" "$PGDATANEW"
#   chmod 700 "$PGDATAOLD" "$PGDATANEW"
   chmod 700 "$PGDATANEW" "$PGDATAOLD"
   chown -R postgres "$PGDATAOLD" "$PGDATANEW"
   chown postgres .

   # restart script as postgres user
   echo -e ""
   echo "Restart script as postgres user."
   exec gosu postgres "$BASH_SOURCE" "$@"
fi

# Collect information from POSTGRES_OLD
# Start DB POSTGRES_OLD
echo -e ""
echo "Start old postgres server."
eval "${PGBINOLD}/pg_ctl -D ${PGDATAOLD} -l logfile start"

# Wait 3 sec for init
sleep 3

# Get default DB encoding and local
ENCODING=$(eval "${PGBINOLD}/psql -t $PGUSER -c 'SHOW SERVER_ENCODING'")

### === Since Postgres 16 does not support 'SHOW LC_COLLATE' ===
#LOCALE=$(eval "${PGBINOLD}/psql -t $PGUSER -c 'SHOW LC_COLLATE'")
#export LOCALE=$(echo ${LOCALE}| xargs)

export ENCODING=$(echo ${ENCODING}| xargs)

# Stop DB POSTGRES_OLD
echo -e ""
echo "Stop old postgres server."
eval "${PGBINOLD}/pg_ctl -D ${PGDATAOLD} -l logfile stop"

# Init DB POSTGRES_NEW  
if [ "${DB_INIT}" == 'true' ]; then
   ENCODING="${ENCODING:=SQL_ASCII}"
   LOCALE="${LOCALE:=en_US.utf8}"
   echo -e ""
   echo "Init new postgres server"
   eval "${PGBINNEW}/initdb --username=${PGUSER} --pgdata=${PGDATANEW} --encoding=${ENCODING} --lc-collate=${LOCALE} --lc-ctype=${LOCALE}"
fi

# run pg_upgrade or launch CMD
if [ "$1" = 'pg_upgrade' ] ;then
   # Upgrade DB POSTGRES_OLD into POSTGRES_NEW
   echo -e ""
   echo "Upgrade pld postgres DB to new postgres db version"
   eval "/usr/lib/postgresql/${POSTGRES_NEW}/bin/pg_upgrade"
else
   exec "$@"
fi

## Update pg config listen_address
#sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" ${PGDATANEW}/postgresql.conf
#
## Update pg_hba for docker (to improve)
#cat << EOF >> ${PGDATANEW}/pg_hba.conf
#host	all		all		192.168.0.0/16		trust
#host	all		all		172.17.0.0/16		trust
#EOF
#chown postgres:postgres ${PGDATANEW}/pg_hba.conf
