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
  echo "=== Instalación automática completa de Joomla 4 (sin instalador web) ==="

  # Variables preguntadas al usuario
  read -p "Dominio o URL del sitio Joomla (ej: localhost o joomla.local): " SITE_URL
  SITE_URL=${SITE_URL:-localhost}

  read -p "Puerto en el que quieres que corra Joomla (ej: 80): " SITE_PORT
  SITE_PORT=${SITE_PORT:-80}

  read -p "Ruta de instalación (fija: /var/www/html): " WEB_ROOT
  WEB_ROOT=${WEB_ROOT:-/var/www/html}

  read -p "Título del sitio Joomla: " SITE_TITLE
  SITE_TITLE=${SITE_TITLE:-Joomla Site}

  read -p "Nombre de la base de datos para Joomla: " DB_NAME
  DB_NAME=${DB_NAME:-joomladb}

  read -p "Usuario de base de datos: " DB_USER
  DB_USER=${DB_USER:-joomlauser}

  read -s -p "Contraseña de base de datos: " DB_PASS
  echo ""

  read -p "Prefijo para tablas (ej: jos_): " DB_PREFIX
  DB_PREFIX=${DB_PREFIX:-jos_}

  read -p "Usuario administrador Joomla (ej: admin): " ADMIN_USER
  ADMIN_USER=${ADMIN_USER:-admin}

  read -s -p "Contraseña administrador Joomla: " ADMIN_PASS
  echo ""
  read -p "Email administrador: " ADMIN_EMAIL
  ADMIN_EMAIL=${ADMIN_EMAIL:-admin@localhost}

  # Crear directorio web (si no existe) y limpiar
  rm -rf "${WEB_ROOT}"/*
  mkdir -p "${WEB_ROOT}"
  chown -R www-data:www-data "${WEB_ROOT}"
  chmod -R 755 "${WEB_ROOT}"

  # Crear base de datos y usuario
  echo "Creando base de datos y usuario MySQL..."
  mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
  mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
  mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';"
  mysql -u root -e "FLUSH PRIVILEGES;"

  # Descargar Joomla (seguir redirecciones) — ajusta la URL si quieres fijar versión
  echo "Descargando Joomla..."
  # Intentamos URL con latest y -L para redirecciones
  TMPZIP="/tmp/joomla.zip"
  wget -qL "https://downloads.joomla.org/cms/joomla4/latest" -O "${TMPZIP}"

  # Verificar descarga
  if [ ! -s "${TMPZIP}" ]; then
    echo "La descarga automática con 'latest' falló. Intentando enlace directo estándar..."
    # Ejemplo de enlace directo (puedes actualizar versión si hace falta)
    wget -qL "https://downloads.joomla.org/cms/joomla4/4-4-14/Joomla_4-4-14-Stable-Full_Package.zip" -O "${TMPZIP}"
  fi

  if [ ! -s "${TMPZIP}" ]; then
    echo "Error: no se pudo descargar Joomla. Revisa la URL o tu conexión."
    return 1
  fi

  echo "Descomprimiendo Joomla en ${WEB_ROOT}..."
  unzip -q "${TMPZIP}" -d "${WEB_ROOT}"
  if [ $? -ne 0 ]; then
    echo "Error al descomprimir ${TMPZIP}"
    return 1
  fi

  # Buscar archivo SQL dentro del paquete descomprimido (busca archivos .sql)
  SQL_SRC=$(find "${WEB_ROOT}" -type f -iname "*.sql" | grep -i "mysql" | head -n 1)
  if [ -z "${SQL_SRC}" ]; then
    # si no encuentra mysql-named, busca cualquier sql
    SQL_SRC=$(find "${WEB_ROOT}" -type f -iname "*.sql" | head -n 1)
  fi

  if [ -z "${SQL_SRC}" ]; then
    echo "No se encontró archivo .sql en el paquete. Imposible importar tablas automáticamente."
    echo "Tendrás que completar la instalación vía web."
    return 1
  fi

  echo "Archivo SQL encontrado: ${SQL_SRC}"

  # Preparamos SQL reemplazando el placeholder #__ por el prefijo elegido
  SQL_TMP="/tmp/joomla_sql_for_import.sql"
  sed "s/#__/${DB_PREFIX}/g" "${SQL_SRC}" >"${SQL_TMP}"

  # Importar SQL en la base de datos creada
  echo "Importando tablas en la base de datos ${DB_NAME} (esto puede tardar)..."
  mysql -u root "${DB_NAME}" <"${SQL_TMP}"
  if [ $? -ne 0 ]; then
    echo "Error al importar SQL. Salida del import: $?"
    return 1
  fi

  # Generar secret y otros valores
  SECRET=$(php -r "echo bin2hex(random_bytes(16));")
  TMP_PATH="${WEB_ROOT}/tmp"
  LOG_PATH="${WEB_ROOT}/logs"
  mkdir -p "${TMP_PATH}" "${LOG_PATH}"
  chown -R www-data:www-data "${TMP_PATH}" "${LOG_PATH}"

  # Crear configuration.php (clase JConfig)
  echo "Generando configuration.php..."
  cat >"${WEB_ROOT}/configuration.php" <<PHPCONF
<?php
class JConfig {
    public \$offline = '0';
    public \$editor = 'tinymce';
    public \$list_limit = '20';
    public \$helpurl = 'https://help.joomla.org/';
    public \$debug = '0';
    public \$debug_lang = '0';
    public \$dbtype = 'mysqli';
    public \$host = 'localhost';
    public \$user = '${DB_USER}';
    public \$password = '${DB_PASS}';
    public \$db = '${DB_NAME}';
    public \$dbprefix = '${DB_PREFIX}';
    public \$live_site = '';
    public \$secret = '${SECRET}';
    public \$gzip = '0';
    public \$error_reporting = 'default';
    public \$xmlrpc_server = '0';
    public \$tmp_path = '${TMP_PATH}';
    public \$log_path = '${LOG_PATH}';
    public \$offset = 'UTC';
    public \$mailer = 'mail';
    public \$mailfrom = '${ADMIN_EMAIL}';
    public \$fromname = '${SITE_TITLE}';
    public \$sendmail = '/usr/sbin/sendmail';
    public \$smtpauth = '0';
    public \$smtpuser = '';
    public \$smtppass = '';
    public \$smtphost = 'localhost';
    public \$smtpsecure = 'none';
    public \$smtpport = '25';
    public \$caching = '0';
    public \$cache_handler = 'file';
    public \$cachetime = '15';
    public \$MetaDesc = '';
    public \$MetaKeys = '';
    public \$sitename = '${SITE_TITLE}';
    public \$captcha = '0';
    public \$session_handler = 'database';
    public \$passwords_min_length = '8';
}
PHPCONF

  chown www-data:www-data "${WEB_ROOT}/configuration.php"
  chmod 644 "${WEB_ROOT}/configuration.php"

  # Crear usuario administrador usando PHP para generar hash y luego SQL
  echo "Creando usuario administrador en la base de datos..."
  # Generar hash de contraseña con PHP (bcrypt)
  PASS_HASH=$(php -r "echo password_hash('${ADMIN_PASS}', PASSWORD_BCRYPT);")

  # Insertar usuario en tabla prefijada ${DB_PREFIX}users
  # Las columnas pueden variar entre versiones; se usa un INSERT con campos comunes.
  SQL_INSERT_USER="INSERT INTO \`${DB_NAME}\`.\`${DB_PREFIX}users\` (
        name, username, email, password, block, sendEmail, registerDate, lastvisitDate, activation, params
    ) VALUES (
        '${ADMIN_USER}', '${ADMIN_USER}', '${ADMIN_EMAIL}', '${PASS_HASH}', 0, 1, NOW(), '0000-00-00 00:00:00', '', ''
    );"

  # Ejecutar inserción
  mysql -u root -D "${DB_NAME}" -e "${SQL_INSERT_USER}"
  if [ $? -ne 0 ]; then
    echo "Advertencia: fallo al insertar usuario en ${DB_PREFIX}users. Intenta revisarlo manualmente."
  else
    # Obtener el id del usuario insertado
    USER_ID=$(mysql -u root -N -s -D "${DB_NAME}" -e "SELECT id FROM \`${DB_PREFIX}users\` WHERE username='${ADMIN_USER}' LIMIT 1;")
    if [ -n "${USER_ID}" ]; then
      # Asignar super user (group_id 8 normalmente es 'Super Users' en Joomla)
      mysql -u root -D "${DB_NAME}" -e "INSERT INTO \`${DB_PREFIX}user_usergroup_map\` (user_id, group_id) VALUES (${USER_ID}, 8);"
      echo "Usuario administrador creado (id: ${USER_ID})."
    else
      echo "No se pudo recuperar el id del usuario admin insertado. Quizá la tabla tenga otro esquema."
    fi
  fi

  # Ajustes finales: permisos, Apache VirtualHost, módulos y reinicio
  echo "Configurando VirtualHost..."
  cat <<EOF >/etc/apache2/sites-available/joomla.conf
<VirtualHost *:${SITE_PORT}>
    ServerName ${SITE_URL}
    DocumentRoot ${WEB_ROOT}
    <Directory ${WEB_ROOT}>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

  a2ensite joomla.conf >/dev/null 2>&1 || true
  a2enmod rewrite >/dev/null 2>&1 || true

  systemctl restart apache2.service

  echo ""
  echo "=========================================="
  echo "Joomla debería estar instalado en:"
  echo "  http://${SITE_URL}:${SITE_PORT}"
  echo ""
  echo "Base de datos: ${DB_NAME}"
  echo "DB user: ${DB_USER}"
  echo "DB prefix: ${DB_PREFIX}"
  echo "Admin user: ${ADMIN_USER}"
  echo "Admin email: ${ADMIN_EMAIL}"
  echo "=========================================="
  echo ""
  echo "Si al abrir la URL ves aún el instalador web, comprueba los logs en ${LOG_PATH} y revisa que"
  echo "- las tablas fueron creadas correctamente (prefijo '${DB_PREFIX}')."
  echo "- el archivo configuration.php existe y contiene las credenciales correctas."
  echo ""
  echo "Nota: Si la creación automática del admin falla por diferencias de esquema entre versiones,"
  echo "podrás crear el admin manualmente desde la base de datos o desde la UI una vez el instalador"
  echo "esté avanzado o terminado."
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
