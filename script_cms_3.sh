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
rm -rf /var/www/html
mkdir -p /var/www/html

# Función para instalar Joomla
#instalar_joomla() {
#  echo "Descargando Joomla..."
#  wget -q https://downloads.joomla.org/cms/joomla4/latest/joomla.zip -O /tmp/joomla.zip
#  unzip /tmp/joomla.zip -d /var/www/html/
#
#  echo "Creando VirtualHost de Joomla..."
#  cat <<EOF >/etc/apache2/sites-available/joomla.conf
#<VirtualHost *:80>
#    ServerName joomla.local
#    DocumentRoot /var/www/html
#    <Directory /var/www/html>
#        AllowOverride All
#        Require all granted
#    </Directory>
#</VirtualHost>
#EOF
#
#  a2ensite joomla.conf
#  a2enmod rewrite
#}
#instalar_joomla() {
#  # Preguntas al usuario
#  read -p "Dominio o URL del sitio Joomla (ej: localhost o joomla.local): " SITE_URL
#  SITE_URL=${SITE_URL:-localhost}
#
#  read -p "Puerto en el que quieres que corra Joomla (ej: 80): " SITE_PORT
#  SITE_PORT=${SITE_PORT:-80}
#
#  read -p "Título del sitio Joomla: " SITE_TITLE
#
#  echo ""
#  echo "⚠️ Joomla no permite configurar usuario/contraseña admin automáticamente desde CLI."
#  echo "Deberás crear el usuario admin y la contraseña en el instalador web después de acceder a la URL."
#  echo ""
#
#  # Descargar Joomla
#  echo "Descargando Joomla..."
#  wget -q https://downloads.joomla.org/cms/joomla4/latest/joomla.zip -O /tmp/joomla.zip
#  unzip -q /tmp/joomla.zip -d /var/www/html/
#
#  # Ajustar permisos
#  chown -R www-data:www-data /var/www/html
#  chmod -R 755 /var/www/html
#
#  # Crear VirtualHost
#  echo "Creando VirtualHost de Joomla en el puerto ${SITE_PORT}..."
#  cat <<EOF >/etc/apache2/sites-available/joomla.conf
#<VirtualHost *:${SITE_PORT}>
#    ServerName ${SITE_URL}
#    DocumentRoot /var/www/html
#    <Directory /var/www/html>
#        AllowOverride All
#        Require all granted
#    </Directory>
#</VirtualHost>
#EOF
#
#  # Activar sitio y módulo rewrite
#  a2ensite joomla.conf
#  a2enmod rewrite
#
#  # Reiniciar Apache
#  systemctl restart apache2.service
#
#  echo ""
#  echo "✅ Joomla está listo en http://${SITE_URL}:${SITE_PORT}"
#  echo "Accede a la URL para completar la instalación web y configurar usuario/contraseña admin."
#}

instalar_joomla() {
  echo "=== Instalación automatizada de Joomla ==="

  # Preguntar variables al usuario
  read -p "Dominio o URL del sitio Joomla (ej: localhost o joomla.local): " SITE_URL
  SITE_URL=${SITE_URL:-localhost}

  read -p "Puerto en el que quieres que corra Joomla (ej: 80): " SITE_PORT
  SITE_PORT=${SITE_PORT:-80}

  read -p "Título del sitio Joomla: " SITE_TITLE

  read -p "Nombre de la base de datos para Joomla: " DB_NAME
  DB_NAME=${DB_NAME:-joomladb}

  read -p "Usuario de base de datos: " DB_USER
  DB_USER=${DB_USER:-joomlauser}

  read -s -p "Contraseña de base de datos: " DB_PASS
  echo ""

  # Crear base de datos y usuario en MySQL
  echo "Creando base de datos y usuario..."
  mysql -u root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';"
  mysql -u root -e "FLUSH PRIVILEGES;"

  # Descargar Joomla
  echo "Descargando Joomla..."
  wget -qL https://downloads.joomla.org/cms/joomla4/4-4-14/Joomla_4-4-14-Stable-Full_Package.zip?format=zip -O /tmp/joomla.zip
  unzip -q /tmp/joomla.zip -d /var/www/html/

  # Ajustar permisos
  chown -R www-data:www-data /var/www/html
  chmod -R 755 /var/www/html

  # Crear VirtualHost Apache
  echo "Creando VirtualHost de Joomla en el puerto ${SITE_PORT}..."
  cat <<EOF >/etc/apache2/sites-available/joomla.conf
<VirtualHost *:${SITE_PORT}>
    ServerName ${SITE_URL}
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

  # Activar sitio y mod_rewrite
  a2ensite joomla.conf
  a2enmod rewrite

  # Reiniciar Apache
  systemctl restart apache2.service

  echo ""
  echo "✅ Joomla está listo en http://${SITE_URL}:${SITE_PORT}"
  echo "Ahora abre esta URL en el navegador y completa la instalación web."
  echo "La base de datos ya fue creada: ${DB_NAME} (usuario: ${DB_USER})"
  echo "Deberás crear el usuario administrador desde el instalador web."
}

# Función para instalar WordPress con preguntas al usuario
instalar_wordpress() {
  echo "Descargando WordPress..."
  wget -q https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz
  tar -xzf /tmp/wordpress.tar.gz -C /tmp/
  cp -r /tmp/wordpress/* /var/www/html/

  # Preguntar variables al usuario
  read -p "URL del sitio (ej: http://localhost o http://miweb.local): " SITE_URL
  read -p "Puerto del sitio Wordpress (Por defecto: 80): " SITE_PORT
  read -p "Título del sitio: " SITE_TITLE
  read -p "Usuario administrador: " ADMIN_USER
  read -s -p "Contraseña administrador: " ADMIN_PASS
  echo ""
  read -p "Correo administrador: " ADMIN_EMAIL
  read -p "Idioma del sitio (ej: es_ES): " SITE_LANG

  # Crear base de datos y usuario
  DB_NAME="wordpressdb"
  DB_USER="wpuser"
  DB_PASS="wpPass123"
  DB_HOST="localhost"

  mysql -u root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
  mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';"
  mysql -u root -e "FLUSH PRIVILEGES;"

  # Instalar WP-CLI
  if ! command -v wp &>/dev/null; then
    echo "Instalando WP-CLI..."
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
  fi

  cd /var/www/html

  # Crear wp-config.php
  wp config create \
    --dbname="${DB_NAME}" \
    --dbuser="${DB_USER}" \
    --dbpass="${DB_PASS}" \
    --dbhost="${DB_HOST}" \
    --skip-check \
    --allow-root

  # Instalación automática de WordPress
  wp core install \
    --url="${SITE_URL}:${SITE_PORT:-80}" \
    --title="${SITE_TITLE}" \
    --admin_user="${ADMIN_USER}" \
    --admin_password="${ADMIN_PASS}" \
    --admin_email="${ADMIN_EMAIL}" \
    --locale="${SITE_LANG}" \
    --skip-email \
    --allow-root

  # VirtualHost Apache
  cat <<EOF >/etc/apache2/sites-available/wordpress.conf
<VirtualHost *:${SITE_PORT:-80}>
    ServerName wordpress.local
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

  a2ensite wordpress.conf
  a2enmod rewrite
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

# Ajustes de permisos
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Reiniciar Apache
systemctl restart apache2.service

echo ""
echo "========================================="
echo " Instalación completada correctamente. 🎉"
echo " Accede a tu sitio: ${SITE_URL}:${SITE_PORT} 🎉"
echo "========================================="
