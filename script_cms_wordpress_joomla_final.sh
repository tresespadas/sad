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
  echo "[+] Instalación automática de Joomla"

  # --- Preguntas al usuario ---
  read -p "[!] Dominio o subdominio (ej: joomla.local): " j_domain
  read -p "[!] Puerto para Joomla (ej: 80, 8080, 9000…): " j_port
  j_port=${j_port:-80}
  read -p "[!] Nombre del sitio: " j_site_name
  #read -p "[!] Usuario administrador: " j_admin_user
  j_admin_user='admin'
  #read -s -p "[!] Contraseña administrador: " j_admin_pass
  j_admin_pass='asDF!123135#e'
  #echo
  #read -p "[!] Email administrador: " j_admin_email
  j_admin_email='admin@local.org'
  #read -p "[!] Nombre de la base de datos: " j_db_name
  j_db_name=bbdd_joomla
  #read -p "[!] Usuario de la base de datos: " j_db_user
  j_db_user=usuario1234
  #read -s -p "[!] Contraseña de la base de datos: " j_db_pass
  j_db_pass='bbdd_passw0rd'
  echo
  #read -p "[!] Prefijo de tablas (por defecto: jos_): " j_db_prefix
  #j_db_prefix=${j_db_prefix:-jos_}
  j_db_prefix='jos_'

  # --- Descarga última versión de Joomla  ---
  echo "[+] Descargando Joomla ..."
  wget -q https://downloads.joomla.org/latest -O /tmp/joomla_latest.zip
  if [ ! -f /tmp/joomla_latest.zip ] || [ $(stat -c%s /tmp/joomla_latest.zip) -lt 1000000 ]; then
    # Fallback por si falla el redirect
    wget -qL https://downloads.joomla.org/cms/joomla4/4-4-14/Joomla_4-4-14-Stable-Full_Package.zip?format=zip -O /tmp/joomla_latest.zip
  fi

  # --- Preparar directorio ---
  rm -rf /var/www/joomla
  mkdir -p /var/www/joomla
  unzip -q /tmp/joomla_latest.zip -d /var/www/joomla
  rm /tmp/joomla_latest.zip

  # --- Base de datos ---
  echo "[+] Creando base de datos y usuario..."
  mysql -u root <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`${j_db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS '${j_db_user}'@'localhost' IDENTIFIED BY '${j_db_pass}';
    GRANT ALL PRIVILEGES ON \`${j_db_name}\`.* TO '${j_db_user}'@'localhost';
    FLUSH PRIVILEGES;
EOSQL

  # --- Instalación vía CLI de Joomla ---
  echo "[+] Instalando Joomla vía línea de comandos..."
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

  # Eliminar carpeta de instalación
  rm -rf /var/www/joomla/installation

  # --- Permisos correctos ---
  chown -R www-data:www-data /var/www/joomla
  find /var/www/joomla -type d -exec chmod 755 {} \;
  find /var/www/joomla -type f -exec chmod 644 {} \;

  # --- Añadir al /etc/hosts automáticamente ---
  if ! grep -q "${j_domain}" /etc/hosts; then
    echo "127.0.0.1        ${j_domain} www.${j_domain}" >>/etc/hosts
    echo "[+] Añadido ${j_domain} al /etc/hosts"
  fi

  read -p "[!] Nombre del archivo .conf (ej. joomla.conf): " NOM_CONF
  # --- VirtualHost perfecto para Joomla ---
  cat >/etc/apache2/sites-available/${NOM_CONF} <<EOF
<VirtualHost *:${j_port}>
  ServerName ${j_domain}
  ServerAlias www.${j_domain}
  DocumentRoot /var/www/joomla

  <Directory /var/www/joomla>
      Options Indexes FollowSymLinks
      AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/joomla_error.log
    CustomLog \${APACHE_LOG_DIR}/joomla_access.log combined
</VirtualHost>
EOF

  # Forzar que Apache escuche en el puerto elegido
  if ! grep -q "Listen ${j_port}" /etc/apache2/ports.conf >/dev/null; then
    echo "Listen ${j_port}" >>/etc/apache2/ports.conf
    echo "[+] Apache ahora escucha en el puerto ${j_port}"
  fi

  # --- Activar sitio y desactivar el por defecto ---
  a2dissite 000-default.conf &>/dev/null || true
  a2ensite ${NOM_CONF}
  a2enmod rewrite >/dev/null
  systemctl restart apache2

  echo
  echo "=============================================="
  echo " Joomla 5 instalado correctamente!"
  echo " URL: http://${j_domain}:${j_port}"
  echo " Administrador: http://${j_domain}:${j_port}/administrator"
  echo " Usuario: ${j_admin_user}"
  echo "=============================================="
  echo
}

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
  #read -p "[!] Usuario administrador: " ADMIN_USER
  ADMIN_USER='admin'
  #read -s -p "[!] Contraseña administrador: " ADMIN_PASS
  #echo
  ADMIN_PASS='asdF12345!%'
  #read -p "[!] Email administrador: " ADMIN_EMAIL
  ADMIN_EMAIL='admin@wordpress.org'
  #read -p "[!] Idioma (ej: es_ES, en_US…): " SITE_LANG
  SITE_LANG='es_ES'

  # Base de datos
  read -p "[!] Nombre de la base de datos: " DB_NAME
  #DB_NAME=bbdd_wordpress
  #read -p "[!] Usuario de la base de datos: " DB_USER
  DB_USER='user'
  #read -s -p "[!] Contraseña de la base de datos: " DB_PASS
  #echo
  DB_PASS='bbdd_passw0rd'
  DB_HOST=localhost

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

  PORT=${SITE_PORT}
  if [[ PORT -eq 80 ]]; then
    sudo -u www-data wp option update home "http://${SITE_URL}" --allow-root
    sudo -u www-data wp option update siteurl "http://${SITE_URL}" --allow-root
  else
    sudo -u www-data wp option update home "http://${SITE_URL}:${SITE_PORT}" --allow-root
    sudo -u www-data wp option update siteurl "http://${SITE_URL}:${SITE_PORT}" --allow-root
  fi

  # Permisos
  chown -R www-data:www-data /var/www/wordpress
  find /var/www/wordpress -type d -exec chmod 755 {} \;
  find /var/www/wordpress -type f -exec chmod 644 {} \;
  chmod 660 /var/www/wordpress/wp-config.php

  # Añadir a /etc/hosts
  if ! grep -q "${SITE_URL}" /etc/hosts; then
    echo "127.0.0.1        ${SITE_URL} www.${SITE_URL}" >>/etc/hosts
    echo "[+] Añadido ${SITE_URL} al /etc/hosts"
  fi

  read -p "[!] Nombre del archivo .conf (ej. wordpress.conf): " NOM_CONF
  # VirtualHost perfecto para WordPress
  cat >/etc/apache2/sites-available/${NOM_CONF} <<EOF
<VirtualHost *:${SITE_PORT}>
    ServerName ${SITE_URL}
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

  # Forzar que Apache escuche en el puerto elegido
  if ! grep -q "Listen ${SITE_PORT}" /etc/apache2/ports.conf >/dev/null; then
    echo "Listen ${SITE_PORT}" >>/etc/apache2/ports.conf
    echo "[+] Apache ahora escucha en el puerto ${SITE_PORT}"
  fi

  # ¡Importantísimo! Desactivamos el sitio por defecto
  a2dissite 000-default.conf &>/dev/null || true
  a2ensite ${NOM_CONF}
  a2enmod rewrite

  systemctl restart apache2

  echo
  echo "=============================================="
  echo " ¡WordPress instalado y configurado correctamente!"
  echo " URL → http://${SITE_URL}:${SITE_PORT}"
  echo " Usuario → ${ADMIN_USER}"
  echo " Contraseña del usuario → ${ADMIN_PASS}"
  echo " Nombre de la BBDD → ${DB_NAME}"
  echo " Contraseña de la BBDD → ${DB_PASS}"
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
