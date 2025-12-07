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

instalar_joomla() {

  echo "📌 Instalación automática de Joomla 4"

  # --- Datos solicitados al usuario ---
  read -p "🔤 Nombre del sitio Joomla: " j_site_name
  read -p "👤 Usuario administrador: " j_admin_user
  read -p "📧 Email administrador: " j_admin_email
  read -s -p "🔑 Password administrador: " j_admin_pass
  echo

  read -p "🗄 Nombre de la base de datos: " j_db_name
  read -p "🗄 Usuario de la base de datos: " j_db_user
  read -s -p "🔑 Password del usuario de la BD: " j_db_pass
  echo
  read -p "🏷 Prefijo de tablas (ej: jos_): " j_db_prefix

  read -p "🌐 URL del sitio (ej: midominio.com): " j_domain
  read -p "🔌 Puerto Apache para Joomla: " j_port

  echo "📥 Descargando Joomla 4..."
  wget -qL "https://downloads.joomla.org/cms/joomla4/4-4-14/Joomla_4-4-14-Stable-Full_Package.zip" -O /tmp/joomla.zip

  echo "📦 Descomprimiendo..."
  rm -rf /var/www/html
  mkdir /var/www/html
  unzip -q /tmp/joomla.zip -d /var/www/html

  echo "🗃 Creando base de datos y usuario..."
  mysql -u root -e "CREATE DATABASE IF NOT EXISTS ${j_db_name} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql -u root -e "CREATE USER IF NOT EXISTS '${j_db_user}'@'localhost' IDENTIFIED BY '${j_db_pass}';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON ${j_db_name}.* TO '${j_db_user}'@'localhost';"
  mysql -u root -e "FLUSH PRIVILEGES;"

  echo "⚙️ Ajustando permisos..."
  chown -R www-data:www-data /var/www/html
  chmod -R 755 /var/www/html

  echo "⚙️ Instalando Joomla vía CLI..."
  cd /var/www/html
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
    --db-prefix="${j_db_prefix}" \
    --db-encryption=0

  echo "🧹 Eliminando carpeta de instalación..."
  rm -rf /var/www/html/installation

  echo "📝 Creando VirtualHost..."
  cat >/etc/apache2/sites-available/joomla.conf <<EOF
<VirtualHost *:${j_port}>
    ServerName ${j_domain}
    DocumentRoot /var/www/html

    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/joomla_error.log
    CustomLog \${APACHE_LOG_DIR}/joomla_access.log combined
</VirtualHost>
EOF

  echo "🔧 Activando sitio Joomla..."
  a2ensite joomla.conf
  systemctl reload apache2

  echo "🎉 Joomla ha sido instalado automáticamente."
  echo "👉 Accede a: http://${j_domain}:${j_port}"
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
