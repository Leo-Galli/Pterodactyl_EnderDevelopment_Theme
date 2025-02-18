#!/bin/bash

# Variabili per i percorsi
PTERO_DIR="/var/www/pterodactyl"
BACKUP_DIR="/var/backups/pterodactyl"
LOG_DIR="/var/log/pterodactyl"
NGINX_LOG="/var/log/nginx/error.log"
MYSQL_LOG="/var/log/mysql/error.log"
REDIS_LOG="/var/log/redis/redis-server.log"

# Funzione di logging
log() {
    echo "$(date) - $1"
}

# Backup delle cartelle contenenti server, nodi e configurazione
log "Avvio del backup delle cartelle server, nodi e configurazione..."
mkdir -p $BACKUP_DIR
cp -r $PTERO_DIR/storage/app $BACKUP_DIR/pterodactyl_app_backup
cp -r $PTERO_DIR/storage/servers $BACKUP_DIR/pterodactyl_servers_backup
cp -r /etc/pterodactyl $BACKUP_DIR/pterodactyl_config_backup
log "Backup completato."

# Arresto dei servizi Pterodactyl e relativi
log "Arrestando i servizi Pterodactyl..."
systemctl stop pterodactyl
systemctl stop nginx
systemctl stop mariadb
systemctl stop redis

# Verifica se i servizi sono stati arrestati correttamente
if systemctl is-active --quiet pterodactyl || systemctl is-active --quiet nginx || systemctl is-active --quiet mariadb || systemctl is-active --quiet redis; then
    log "Errore: Non tutti i servizi sono stati arrestati correttamente!"
    exit 1
else
    log "Servizi arrestati con successo."
fi

# Rimozione della vecchia installazione di Pterodactyl
log "Rimuovendo la vecchia installazione di Pterodactyl..."
rm -rf $PTERO_DIR
log "Installazione precedente rimossa."

# Installazione di Pterodactyl
log "Scaricando e installando Pterodactyl..."
cd /var/www
git clone https://github.com/pterodactyl/panel.git pterodactyl
cd $PTERO_DIR
composer install --no-dev --optimize-autoloader
php artisan key:generate
php artisan migrate --seed --force
log "Pterodactyl reinstallato con successo."

# Ripristino dei backup
log "Ripristinando i backup..."
cp -r $BACKUP_DIR/pterodactyl_app_backup/* $PTERO_DIR/storage/app
cp -r $BACKUP_DIR/pterodactyl_servers_backup/* $PTERO_DIR/storage/servers
cp -r $BACKUP_DIR/pterodactyl_config_backup/* /etc/pterodactyl
log "Ripristino completato."

# Riavvio dei servizi
log "Riavviando i servizi Pterodactyl..."
systemctl start pterodactyl
systemctl start nginx
systemctl start mariadb
systemctl start redis

# Verifica se i servizi sono stati avviati correttamente
if ! systemctl is-active --quiet pterodactyl && ! systemctl is-active --quiet nginx && ! systemctl is-active --quiet mariadb && ! systemctl is-active --quiet redis; then
    log "Errore: Alcuni servizi non sono riusciti ad avviarsi."
    exit 1
else
    log "Servizi riavviati correttamente."
fi

# Controllo dei log di sistema per errori
log "Verificando i log di sistema per errori..."
tail -n 50 $NGINX_LOG
tail -n 50 $MYSQL_LOG
tail -n 50 $REDIS_LOG
log "Controllo dei log completato."

log "Pterodactyl è stato riinstallato con successo senza perdere server e contenuti!"
