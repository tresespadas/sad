#!/bin/bash

# Verificación de usuario root
if [ "$(whoami)" != "root" ]; then
  echo "Debes ejecutar este script como root o usando sudo."
  exit 1
fi

echo "==============================="
echo " Instalador de CMS (WordPress / Joomla)"
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
apt install -y apache2 mariadb-server php php-mysql php-gd php-xml php-mbstring php-curl php-zip

# Reiniciar networking
echo "Reiniciando servicio networking..."
systemctl restart networking.service

# Preparación de directorios
echo "Preparando directorios web..."
rm -rf /var/www/html
mkdir -p /var/www/html

# Función para instalar WordPress
instalar_wordpress() {
  echo "Descargando WordPress..."
  wget -q https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz
  tar -xzf /tmp/wordpress.tar.gz -C /tmp/
  cp -r /tmp/wordpress/* /var/www/html/

  echo "Creando VirtualHost de WordPress..."
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

# Función para instalar Joomla
instalar_joomla() {
  echo "Descargando Joomla..."
  wget -q https://downloads.joomla.org/cms/joomla4/latest/joomla.zip -O /tmp/joomla.zip
  apt install -y unzip
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

# Permisos
echo "Ajustando permisos..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Reiniciar Apache
echo "Reiniciando Apache..."
systemctl restart apache2.service

echo ""
echo "========================================="
echo " Instalación completada correctamente. 🎉"
echo "========================================="
echo ""
