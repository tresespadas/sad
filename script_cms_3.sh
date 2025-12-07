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
instalar_joomla() {
  echo "Descargando Joomla..."
  wget -q https://downloads.joomla.org/cms/joomla4/latest/joomla.zip -O /tmp/joomla.zip
  unzip /tmp/joomla.zip -d /var/www/html/

  echo "Creando VirtualHost de Joomla..."
  cat <<EOF >/etc/apache2/sites-available/joomla.conf
<VirtualHost *:80>
    ServerName joomla.local
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

  a2ensite joomla.conf
  a2enmod rewrite
}

# Función para instalar WordPress con preguntas al usuario
instalar_wordpress() {
  echo "Descargando WordPress..."
  wget -q https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz
  tar -xzf /tmp/wordpress.tar.gz -C /tmp/
  cp -r /tmp/wordpress/* /var/www/html/

  # Preguntar variables al usuario
  read -p "URL del sitio (ej: http://localhost o http://miweb.local): " SITE_URL
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
    --url="${SITE_URL}" \
    --title="${SITE_TITLE}" \
    --admin_user="${ADMIN_USER}" \
    --admin_password="${ADMIN_PASS}" \
    --admin_email="${ADMIN_EMAIL}" \
    --locale="${SITE_LANG}" \
    --skip-email \
    --allow-root

  # VirtualHost Apache
  cat <<EOF >/etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
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
echo "========================================="
