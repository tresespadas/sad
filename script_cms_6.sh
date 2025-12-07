#!/bin/bash

# Verificación de usuario root
if [ "$(whoami)" != "root" ]; then
  echo "Debes ejecutar este script como root o usando sudo."
  exit 1
fi

echo "==============================="
echo " Instalador de WordPress / Joomla"
echo "==============================="
echo ""
echo "¿Qué CMS deseas instalar?"
echo "1) WordPress"
echo "2) Joomla"
read -p "Elige una opción (1/2): " opcion

# Actualización e instalación de paquetes base
echo "Actualizando repositorios..."
apt update -y

echo "Instalando Apache, PHP y MariaDB..."
apt install -y apache2 mariadb-server php php-mysql php-gd php-xml php-mbstring php-curl php-zip unzip wget curl

# Reiniciar networking
echo "Reiniciando servicio networking..."
systemctl restart networking.service

# Preparación de directorios
#rm -rf /var/www/html
#mkdir -p /var/www/html

instalar_joomla() {

  echo "[+] Instalación automática de Joomla 4"

  # --- Datos solicitados al usuario ---
  read -p "[!] Nombre del sitio Joomla: " j_site_name
  read -p "[!] Usuario administrador: " j_admin_user
  read -p "[!] Email administrador: " j_admin_email
  read -s -p "[!] Password administrador: " j_admin_pass
  echo

  read -p "[!] Nombre de la base de datos: " j_db_name
  read -p "[!] Usuario de la base de datos: " j_db_user
  read -s -p "[!] Password del usuario de la BD: " j_db_pass
  echo
  read -p "[!] Prefijo de tablas (por defecto: jos_): " j_db_prefix

  read -p "[!] URL del sitio (ej: midominio.com): " j_domain
  read -p "[!] Puerto para Joomla (por defecto: 80): " j_port

  echo "[+] Descargando Joomla 4..."
  wget -qL "https://downloads.joomla.org/cms/joomla4/4-4-14/Joomla_4-4-14-Stable-Full_Package.zip" -O /tmp/joomla.zip

  echo "[+] Descomprimiendo..."
  #rm -rf /var/www/html
  mkdir -p /var/www/joomla
  unzip -q /tmp/joomla.zip -d /var/www/joomla

  echo "[+] Creando base de datos y usuario..."
  mysql -u root -e "CREATE DATABASE IF NOT EXISTS ${j_db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql -u root -e "CREATE USER IF NOT EXISTS '${j_db_user}'@'localhost' IDENTIFIED BY '${j_db_pass}';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON ${j_db_name}.* TO '${j_db_user}'@'localhost';"
  mysql -u root -e "FLUSH PRIVILEGES;"

  echo "[+] Ajustando permisos..."
  chown -R www-data:www-data /var/www/joomla
  chmod -R 755 /var/www/joomla

  echo "[+] Instalando Joomla vía CLI..."
  cd /var/www/joomla
  php installation/joomla.php install \
    --site-name="${j_site_name}" \
    --admin-user="${j_admin_user}" \
    --admin-username="${j_admin_user}" \
    --admin-password="${j_admin_pass}" \
    --admin-email="${j_admin_email}" \
    --db-type="mysqli" \
    --db-host="localhost" \
    --db-user="${j_db_user}" \
    --db-pass="${j_db_pass}" \
    --db-name="${j_db_name}" \
    --db-prefix="${j_db_prefix:-jos_}" \
    --db-encryption=0

  echo "[+] Eliminando carpeta de instalación..."
  rm -rf /var/www/joomla/installation

  echo "[+] Creando VirtualHost..."
  cat >/etc/apache2/sites-available/joomla.conf <<EOF
<VirtualHost *:${j_port:-80}>
    ServerName ${j_domain}
    ServerAdmin ${j_admin_email}
    DocumentRoot /var/www/joomla

    <Directory /var/www/joomla/>
        DirectoryIndex index.php
        Options Indexes FollowSymLinks Multiviews
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/joomla_error.log
    CustomLog \${APACHE_LOG_DIR}/joomla_access.log combined
</VirtualHost>
EOF

  echo "[+] Activando sitio Joomla..."
  a2ensite joomla.conf
  systemctl reload apache2

  chown -R www-data:www-data /var/www/joomla
  chmod -R 755 /var/www/joomla

  systemctl restart apache2.service
  sleep 2

  echo
  echo "=============================================="
  echo " Joomla ha sido instalado automáticamente."
  echo " Accede a: http://${j_domain}:${j_port}"
  echo "=============================================="
  echo
}

# Función para instalar WordPress con preguntas al usuario
#instalar_wordpress() {
#  echo "[+] Descargando WordPress..."
#  wget -q https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz
#  tar -xzf /tmp/wordpress.tar.gz -C /tmp/
#  mkdir -p /var/www/wordpress
#  cp -r /tmp/wordpress/* /var/www/wordpress/
#
#  # Preguntar variables al usuario
#  read -p "[!] URL del sitio (ej: localhost o miweb.local): " SITE_URL
#  read -p "[!] Puerto del sitio Wordpress (Por defecto: 80): " SITE_PORT
#  read -p "[!] Título del sitio: " SITE_TITLE
#  read -p "[!] Usuario administrador: " ADMIN_USER
#  read -s -p "[!] Contraseña administrador: " ADMIN_PASS
#  echo
#  read -p "[!] Correo administrador: " ADMIN_EMAIL
#  read -p "[!] Idioma del sitio (ej: es_ES): " SITE_LANG
#
#  # Crear base de datos y usuario
#  read -p "[!] Nombre de la base de datos: " DB_NAME
#  read -p "[!] Nombre del usuario de la base de datos: " DB_USER
#  read -s -p "[!] Contraseña del usuario de la base de datos: " DB_PASS
#  echo
#  read -p "[!] Nombre del host de la base de datos (por defecto 'localhost'): " DB_HOST
#
#  mysql -u root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
#  mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
#  mysql -u root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';"
#  mysql -u root -e "FLUSH PRIVILEGES;"
#
#  # Instalar WP-CLI
#  if ! command -v wp &>/dev/null; then
#    echo "[+] Instalando WP-CLI..."
#    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
#    chmod +x wp-cli.phar
#    mv wp-cli.phar /usr/local/bin/wp
#  fi
#
#  cd /var/www/wordpress
#
#  # Crear wp-config.php
#  wp config create \
#    --dbname="${DB_NAME}" \
#    --dbuser="${DB_USER}" \
#    --dbpass="${DB_PASS}" \
#    --dbhost="${DB_HOST:-localhost}" \
#    --skip-check \
#    --allow-root
#
#  # Instalación automática de WordPress
#  wp core install \
#    --url="http://${SITE_URL}:${SITE_PORT:-80}" \
#    --title="${SITE_TITLE}" \
#    --admin_user="${ADMIN_USER}" \
#    --admin_password="${ADMIN_PASS}" \
#    --admin_email="${ADMIN_EMAIL}" \
#    --locale="${SITE_LANG}" \
#    --skip-email \
#    --allow-root
#
#  # VirtualHost Apache
#  cat <<EOF >/etc/apache2/sites-available/wordpress.conf
#<VirtualHost *:${SITE_PORT:-80}>
#    ServerName ${SITE_URL}
#    ServerAdmin ${ADMIN_EMAIL}
#    DocumentRoot /var/www/wordpress
#
#    <Directory /var/www/wordpress/>
#        DirectoryIndex index.php
#        Options Indexes FollowSymLinks Multiviews
#        AllowOverride All
#        Require all granted
#    </Directory>
#
#    ErrorLog \${APACHE_LOG_DIR}/wordpress.log
#    CustomLog \${APACHE_LOG_DIR}/wordpress.log combined
#</VirtualHost>
#EOF
#
#  echo "[+] Activando sitio WordPress"
#  a2ensite wordpress.conf
#  a2enmod rewrite
#
#  chown -R www-data:www-data /var/www/wordpress
#  chmod -R 755 /var/www/wordpress
#
#  systemctl restart apache2.service
#  sleep 2
#
#  echo
#  echo "=============================================="
#  echo " WordPress ha sido instalado automáticamente."
#  echo " Accede a: http://${SITE_URL}:${SITE_PORT:-80}"
#  echo "=============================================="
#  echo
#}

instalar_wordpress() {
  echo "[+] Descargando última versión de WordPress..."
  wget -q https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz
  tar -xzf /tmp/wordpress.tar.gz -C /tmp
  rm -rf /var/www/wordpress
  mv /tmp/wordpress /var/www/wordpress

  # Preguntas al usuario
  read -p "[!] Dominio o subdominio (ej: midominio.com o wp.local): " SITE_URL
  read -p "[!] Puerto (por defecto 80): " SITE_PORT
  SITE_PORT=${SITE_PORT:-80}
  read -p "[!] Título del sitio: " SITE_TITLE
  read -p "[!] Usuario administrador: " ADMIN_USER
  read -s -p "[!] Contraseña administrador: " ADMIN_PASS
  echo
  read -p "[!] Email administrador: " ADMIN_EMAIL
  read -p "[!] Idioma (ej: es_ES, en_US…): " SITE_LANG

  # Base de datos
  read -p "[!] Nombre de la base de datos: " DB_NAME
  read -p "[!] Usuario de la base de datos: " DB_USER
  read -s -p "[!] Contraseña de la base de datos: " DB_PASS
  echo
  DB_HOST=${DB_HOST:-localhost}

  echo "[+] Creando base de datos y usuario..."
  mysql -u root <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
    GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
    FLUSH PRIVILEGES;
EOSQL

  # Instalar WP-CLI si no está
  if ! command -v wp &>/dev/null; then
    echo "[+] Instalando WP-CLI..."
    curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
  fi

  cd /var/www/wordpress

  # wp-config.php + instalación
  wp config create --dbname="${DB_NAME}" --dbuser="${DB_USER}" --dbpass="${DB_PASS}" --dbhost="${DB_HOST}" --locale="${SITE_LANG}" --allow-root --skip-check
  wp core install --url="http://${SITE_URL}:${SITE_PORT}" --title="${SITE_TITLE}" \
    --admin_user="${ADMIN_USER}" --admin_password="${ADMIN_PASS}" \
    --admin_email="${ADMIN_EMAIL}" --skip-email --allow-root

  wp option update home "http://${SITE_URL}:${SITE_PORT:-80}"
  wp option update siteurl "http://${SITE_URL}:${SITE_PORT:-80}"

  # Permisos correctos
  chown -R www-data:www-data /var/www/wordpress
  find /var/www/wordpress -type d -exec chmod 755 {} \;
  find /var/www/wordpress -type f -exec chmod 644 {} \;
  chmod 660 /var/www/wordpress/wp-config.php

  # Añadir a /etc/hosts
  if ! grep -q "${SITE_URL}" /etc/hosts; then
    echo "127.0.0.1        ${SITE_URL} www.${SITE_URL}" >>/etc/hosts
    echo "[+] Añadido ${SITE_URL} al /etc/hosts"
  fi

  # VirtualHost perfecto para WordPress
  cat >/etc/apache2/sites-available/wordpress.conf <<EOF
<VirtualHost *:${SITE_PORT}>
    ServerName ${SITE_URL}
    ServerAlias www.${SITE_URL}
    DocumentRoot /var/www/wordpress

    <Directory /var/www/wordpress>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/wordpress_error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress_access.log combined
</VirtualHost>
EOF

  # ¡Importantísimo! Desactivamos el sitio por defecto
  a2dissite 000-default.conf &>/dev/null || true
  a2ensite wordpress.conf
  a2enmod rewrite

  systemctl restart apache2

  echo
  echo "=============================================="
  echo " ¡WordPress instalado y configurado correctamente!"
  echo " URL → http://${SITE_URL}:${SITE_PORT}"
  #echo " Usuario → ${ADMIN_USER}"
  echo "=============================================="
  echo
}

# Instalación según elección
case "$opcion" in
1)
  echo "Instalando WordPress..."
  instalar_wordpress
  ;;
2)
  echo "Instalando Joomla..."
  instalar_joomla
  ;;
*)
  echo "Opción inválida. Saliendo..."
  exit 1
  ;;
esac
127.0.0.1 localhost
