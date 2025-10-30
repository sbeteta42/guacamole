#!/usr/bin/env bash
#
# Script d'installation automatique d'Apache Guacamole sur Debian 12 par sbeteta@beteta.org alias "shadow"
#  - installer/compilier guacamole-server
#  - installer Tomcat 9 (depuis dépôt Bullseye, car Tomcat 10 pas supporté)
#  - installer la webapp Guacamole
#  - installer MariaDB et l'extension JDBC MySQL
#  - créer la base + l'utilisateur
#  - créer /etc/guacamole + guacamole.properties + guacd.conf
#  - démarrer les services
#
# À lancer en root (sudo -i) ou avec sudo devant.
# Testé/logique pour Debian 12. Adapte les versions si Guacamole évolue.
#

set -euo pipefail

### ====== VARIABLES A ADAPTER SI BESOIN ======
GUAC_VERSION="1.5.5"
GUAC_USER_DB="guaca_nachos"          # utilisateur SQL guacamole
GUAC_DB="guacadb"                    # base guacamole
GUAC_DB_PASS="P@ssword!"             # mot de passe SQL (change-moi)
MYSQL_CONNECTOR_VERSION="9.1.0"
MYSQL_CONNECTOR_FILE="mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz"
MYSQL_CONNECTOR_DIR="mysql-connector-j-${MYSQL_CONNECTOR_VERSION}"
GUAC_DOWNLOAD_BASE="https://downloads.apache.org/guacamole"
MYSQL_CONNECTOR_URL="https://dev.mysql.com/get/Downloads/Connector-J/${MYSQL_CONNECTOR_FILE}"
DEBIAN_CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)

### ====== FONCTIONS UTILES ======
info()  { echo -e "\e[32m[+]\e[0m $*"; }
warn()  { echo -e "\e[33m[!]\e[0m $*"; }
error() { echo -e "\e[31m[ERR]\e[0m $*" >&2; }

if [[ $EUID -ne 0 ]]; then
    error "Ce script doit être exécuté en root (sudo -i)."
    exit 1
fi

info "Début de l'installation d'Apache Guacamole ${GUAC_VERSION} sur Debian (${DEBIAN_CODENAME})"

### 1. MISE A JOUR + PREREQUIS DE COMPILATION
info "Mise à jour des paquets..."
apt-get update -y

info "Installation des dépendances pour guacamole-server (RDP, VNC, SSH, vidéo, etc.)..."
apt-get install -y \
  build-essential libcairo2-dev libjpeg62-turbo-dev libpng-dev libtool-bin uuid-dev \
  libossp-uuid-dev libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
  freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libvncserver-dev \
  libwebsockets-dev libpulse-dev libssl-dev libvorbis-dev libwebp-dev \
  wget curl gnupg lsb-release ca-certificates

### 2. TELECHARGER ET COMPILER GUACAMOLE SERVER
info "Téléchargement de guacamole-server ${GUAC_VERSION}..."
cd /tmp
wget -q ${GUAC_DOWNLOAD_BASE}/${GUAC_VERSION}/source/guacamole-server-${GUAC_VERSION}.tar.gz

info "Décompression..."
tar -xzf guacamole-server-${GUAC_VERSION}.tar.gz
cd guacamole-server-${GUAC_VERSION}

info "Configuration (avec systemd)..."
./configure --with-systemd-dir=/etc/systemd/system/ || {
    warn "configure a échoué : on retente sans guacenc (enregistrements vidéo désactivés)..."
    ./configure --with-systemd-dir=/etc/systemd/system/ --disable-guacenc
}

info "Compilation (cela peut être un peu long)..."
make

info "Installation de guacamole-server..."
make install

info "Mise à jour des liens dynamiques..."
ldconfig

info "Activation du service guacd..."
systemctl daemon-reload
systemctl enable --now guacd

### 3. ARBORESCENCE /etc/guacamole
info "Création de l'arborescence /etc/guacamole..."
mkdir -p /etc/guacamole/{extensions,lib}

### 4. INSTALLATION DE TOMCAT 9 (depuis bullseye car tomcat10 non supporté)
# Le tuto IT-Connect ajoute un dépôt Debian 11 pour récupérer tomcat9. On fait pareil.
if [[ ! -f /etc/apt/sources.list.d/bullseye.list ]]; then
    info "Ajout du dépôt Debian 11 (bullseye) pour Tomcat 9..."
    echo "deb http://deb.debian.org/debian/ bullseye main" > /etc/apt/sources.list.d/bullseye.list
fi

info "Mise à jour des paquets (avec bullseye)..."
apt-get update -y

info "Installation de Tomcat 9..."
apt-get install -y tomcat9 tomcat9-admin tomcat9-common tomcat9-user

### 5. INSTALLATION DE LA WEBAPP GUACAMOLE (fichier .war)
info "Téléchargement de la Web App Guacamole..."
cd /tmp
wget -q ${GUAC_DOWNLOAD_BASE}/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war

info "Déploiement de la Web App dans Tomcat..."
mv guacamole-${GUAC_VERSION}.war /var/lib/tomcat9/webapps/guacamole.war
chown tomcat:tomcat /var/lib/tomcat9/webapps/guacamole.war || true

### 6. INSTALLATION DE MARIADB + CREATION BDD GUACAMOLE
info "Installation du serveur MariaDB..."
apt-get install -y mariadb-server

# Optionnel : tu peux appeler ici mysql_secure_installation en interactif
warn "Pense à lancer 'mysql_secure_installation' plus tard si ce n'est pas déjà fait."

info "Création de la base, de l'utilisateur et des droits..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${GUAC_DB};
CREATE USER IF NOT EXISTS '${GUAC_USER_DB}'@'localhost' IDENTIFIED BY '${GUAC_DB_PASS}';
GRANT SELECT,INSERT,UPDATE,DELETE ON ${GUAC_DB}.* TO '${GUAC_USER_DB}'@'localhost';
FLUSH PRIVILEGES;
EOF

### 7. EXTENSION JDBC GUACAMOLE (MySQL/MariaDB)
info "Téléchargement de l'extension JDBC Guacamole..."
cd /tmp
wget -q ${GUAC_DOWNLOAD_BASE}/${GUAC_VERSION}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz
tar -xzf guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz

info "Copie du .jar d'auth MySQL dans /etc/guacamole/extensions/ ..."
cp guacamole-auth-jdbc-${GUAC_VERSION}/mysql/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar /etc/guacamole/extensions/

### 8. CONNECTEUR MYSQL (obligatoire même avec MariaDB)
info "Téléchargement du connecteur MySQL ${MYSQL_CONNECTOR_VERSION}..."
cd /tmp
wget -q ${MYSQL_CONNECTOR_URL}
tar -xzf ${MYSQL_CONNECTOR_FILE}

info "Copie du connecteur dans /etc/guacamole/lib/ ..."
cp ${MYSQL_CONNECTOR_DIR}/${MYSQL_CONNECTOR_DIR}.jar /etc/guacamole/lib/

### 9. IMPORT DU SCHEMA SQL GUACAMOLE
info "Import du schéma SQL dans la base ${GUAC_DB}..."
cd /tmp/guacamole-auth-jdbc-${GUAC_VERSION}/mysql/schema
cat *.sql | mysql -u root ${GUAC_DB}

### 10. FICHIER /etc/guacamole/guacamole.properties
info "Création / mise à jour de /etc/guacamole/guacamole.properties ..."
cat > /etc/guacamole/guacamole.properties <<EOF
# =========================
# Guacamole configuration
# =========================

# Backend : MySQL/MariaDB
mysql-hostname: 127.0.0.1
mysql-port: 3306
mysql-database: ${GUAC_DB}
mysql-username: ${GUAC_USER_DB}
mysql-password: ${GUAC_DB_PASS}

# Où Guacamole va chercher ses extensions et libs
guacamole-home: /etc/guacamole
EOF

### 11. FICHIER /etc/guacamole/guacd.conf
info "Création / mise à jour de /etc/guacamole/guacd.conf ..."
cat > /etc/guacamole/guacd.conf <<'EOF'
[server]
bind_host = 0.0.0.0
bind_port = 4822
EOF

### 12. DIRE A TOMCAT OU EST GUACAMOLE_HOME
# Deux façons : /etc/default/tomcat9 ou /etc/systemd/system/tomcat9.service.d
# On fait la méthode simple IT-Connect : /etc/default/tomcat9
info "Déclaration de GUACAMOLE_HOME dans /etc/default/tomcat9 ..."
if ! grep -q "GUACAMOLE_HOME" /etc/default/tomcat9 2>/dev/null; then
    echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/tomcat9
else
    sed -i 's|^GUACAMOLE_HOME=.*|GUACAMOLE_HOME=/etc/guacamole|' /etc/default/tomcat9
fi

### 13. REDÉMARRAGE DES SERVICES
info "Redémarrage des services guacd, tomcat9 et mariadb..."
systemctl restart guacd
systemctl restart tomcat9
systemctl restart mariadb

### 14. FIN
ip_addr=$(hostname -I | awk '{print $1}')
info "Installation terminée."
echo
echo "-------------------------------------------------------------"
echo "Apache Guacamole est (normalement) accessible ici :"
echo "  → http://${ip_addr}:8080/guacamole/"
echo "Identifiants par défaut : guacadmin / guacadmin"
echo "Pense à créer un vrai compte admin et à désactiver guacadmin."
echo "-------------------------------------------------------------"

