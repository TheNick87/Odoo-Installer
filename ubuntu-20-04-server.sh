#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Esegui questo script come utente root, oppure usando il comando sudo"
  exit
fi


PYTHON_COMMAND=python3
apt-get -u -y install git python3 python3-pip build-essential wget python3-dev python3-venv python3-virtualenv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libjpeg-dev gdebi
apt-get install -y libpq-dev python-dev libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libffi-dev
apt-get install nodejs npm -y
apt-get -u -y install postgresql-client
npm install -g rtlcss
apt-get install -y xfonts-75dpi
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.bionic_amd64.deb
dpkg -i wkhtmltox_0.12.6-1.bionic_amd64.deb
cp /usr/local/bin/wkhtmltoimage /usr/bin/wkhtmltoimage
cp /usr/local/bin/wkhtmltopdf /usr/bin/wkhtmltopdf

ODOO_ABS_PATH=/opt
PATH_OK=n
while [ -z $PATH_OK ] || [ $PATH_OK != "Y" ]
do
    echo "Inserisci path dove creare la cartella '/odoo' (/opt):"
    read ABS

    if [ -n "$ABS" ]
        then ODOO_ABS_PATH=$ABS
    fi
    ODOO_ABS_PATH+=/odoo
    echo "Odoo path: ${ODOO_ABS_PATH}"
    echo "Confermi (Y/n)? (${PATH_OK})"
    read PATH_OK
done

if [ ! -d "$ODOO_ABS_PATH" ] 
    then 
        mkdir -p "$ODOO_ABS_PATH" 
        #Anche se poi verranno settati ancora, meglio essere sicuri che i permessi siano completi
        chmod -R 777 "$ODOO_ABS_PATH" 
    else 
        echo "La cartella ${ODOO_ABS_PATH} esiste già, vuoi sovrascriverla(Y/n)? (n)"
        read INPUT
        if test INPUT = "Y"
        then
            rm -rf ${ODOO_ABS_PATH}
            mkdir -p "$ODOO_ABS_PATH" 
            #Anche se poi verranno settati ancora, meglio essere sicuri che i permessi siano completi
            chmod -R 777 "$ODOO_ABS_PATH"
        fi
fi

ODOO_USER=odoo
if id "$ODOO_USER" &>/dev/null; then
    echo "User ${ODOO_USER} found!"
else
    echo "User ${ODOO_USER} not found, creating ..."
    adduser -system -home=${ODOO_ABS_PATH} -group ${ODOO_USER}
fi

chown -R ${ODOO_USER}:${ODOO_USER} ${ODOO_ABS_PATH}
cd ${ODOO_ABS_PATH}
echo "Scegli la versione di Python per virtualenv [3.6/3.7/3.8/3.9]"
read INPUT
virtualenv venv --python=python${INPUT} ${ODOO_ABS_PATH}
chmod -R 777 ${ODOO_ABS_PATH} #Ogni tanto toglie alcuni permessi, meglio essere sicuri
#Attivo venv
source ${ODOO_ABS_PATH}/bin/activate

#Inizio con l'installazione vera e propria dei requirements all'interno di venv
pip3 install -r https://raw.githubusercontent.com/odoo/odoo/14.0/requirements.txt

git clone --depth 1 --branch 14.0 https://www.github.com/odoo/odoo

echo "[options]
addons_path = ${ODOO_ABS_PATH}/extras,${ODOO_ABS_PATH}/odoo/odoo/addons,${ODOO_ABS_PATH}/odoo/addons,${ODOO_ABS_PATH}/oca/project
csv_internal_sep = ,
data_dir = /var/lib/odoo
db_host = 127.0.0.1
db_maxconn = 64
db_name = False
db_password = odoo
db_port = 5432
db_sslmode = prefer
db_template = template0
db_user = odoo
dbfilter = 
demo = {}
email_from = False
geoip_database = /usr/share/GeoIP/GeoLite2-City.mmdb
http_enable = True
http_interface = 
http_port = 8069
import_partial = 
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 1200
limit_time_real = 2400
limit_time_real_cron = -1
list_db = True
log_db = False
log_db_level = error
log_handler = :DEBUG
log_level = debug
logfile = 
longpolling_port = 8072
max_cron_threads = 2
osv_memory_age_limit = False
osv_memory_count_limit = False
pg_path = /usr/bin
pidfile = 
proxy_mode = False
reportgz = False
screencasts = 
screenshots = /tmp/odoo_tests
server_wide_modules = base,web
smtp_password = False
smtp_port = 25
smtp_server = localhost
smtp_ssl = False
smtp_user = False
syslog = False
test_enable = False
test_file = 
test_tags = None
transient_age_limit = 1.0
translate_modules = ['all']
unaccent = False
upgrade_path = 
without_demo = False
workers = 0" > ${ODOO_ABS_PATH}/odoo/odoo.conf

chmod -R 777 ${ODOO_ABS_PATH}
chown -R odoo:odoo ${ODOO_ABS_PATH}

cd ${ODOO_ABS_PATH}
mkdir -p ${ODOO_ABS_PATH}/oca
cd ${ODOO_ABS_PATH}/oca
git clone --depth=1 -b 14.0 https://github.com/OCA/project.git

chmod -R 777 ${ODOO_ABS_PATH}/oca
chown -R odoo:odoo ${ODOO_ABS_PATH}/oca

mkdir -p /var/lib/odoo
chmod -R 777 /var/lib/odoo
chown -R odoo:odoo /var/lib/odoo

# =======================================================================================
# Odoo adesso è installato
# Installazione PostgreSQL
# =======================================================================================

#Su Ubuntu 20.04 non c'è più possibilità di installare PostgreSQL 10.0, ma Odoo non è
#compatibile al 100% con la 12, quindi userò un docker con l'immagine di pg

echo "version: '2'

services:
    db10:
        image: postgres:10.0
        ports:
           - 5432:5432
        environment:
        - POSTGRES_USER=odoo
        - POSTGRES_PASSWORD=odoo
        - POSTGRES_DB=postgres
        volumes:
        - \"pg10:/var/lib/postgresql/data\"

volumes:
    pg10:" > ${ODOO_ABS_PATH}/docker-compose.yml

chmod 777 ${ODOO_ABS_PATH}/docker-compose.yml
