#!/bin/bash

clear

echo "======================================"
echo "  Instalador de CMS: WordPress/Joomla "
echo "======================================"
echo ""
echo "1) Instalar WordPress"
echo "2) Instalar Joomla"
echo ""
read -p "Elige una opción (1-2): " opcion

# Función para instalar dependencias comunes
instalar_dependencias() {
  echo "[+] Instalando paquetes necesarios..."
  sudo apt update
  sudo apt install -y apache2 mysql-server php php-mysql php-xml php-cli php-zip php-curl php-gd php-mbstring unzip wget
}

# Función para crear base de datos
crear_db() {
  read -p "Nombre de la base de datos: " dbname
  read -p "Usuario de la base de datos: " dbuser
  read -s -p "Contraseña del usuario: " dbpass
  echo ""

  sudo mysql -e "CREATE DATABASE ${dbname};"
  sudo mysql -e "CREATE USER '${dbuser}'@'localhost' IDENTIFIED BY '${dbpass}';"
  sudo mysql -e "GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbuser}'@'localhost';"
  sudo mysql -e "FLUSH PRIVILEGES;"

  echo "[+] Base de datos creada correctamente."
}

# Función para instalar WordPress
instalar_wordpress() {
  echo "[+] Descargando WordPress..."
  wget https://wordpress.org/latest.zip -O /tmp/wordpress.zip
  unzip /tmp/wordpress.zip -d /tmp/

  echo "[+] Copiando archivos a /var/www/html..."
  sudo rm -rf /var/www/html/*
  sudo cp -r /tmp/wordpress/* /var/www/html/

  sudo chown -R www-data:www-data /var/www/html/

  echo "[+] WordPress instalado."
}

# Función para instalar Joomla
instalar_joomla() {
  echo "[+] Descargando Joomla..."
  wget https://downloads.joomla.org/cms/joomla5/latest/Joomla_5-Stable-Full_Package.zip?format=zip -O /tmp/joomla.zip
  unzip /tmp/joomla.zip -d /tmp/joomla/

  echo "[+] Copiando archivos a /var/www/html..."
  sudo rm -rf /var/www/html/*
  sudo cp -r /tmp/joomla/* /var/www/html/

  sudo chown -R www-data:www-data /var/www/html/

  echo "[+] Joomla instalado."
}

case $opcion in
1)
  instalar_dependencias
  crear_db
  instalar_wordpress
  ;;
2)
  instalar_dependencias
  crear_db
  instalar_joomla
  ;;
*)
  echo "Opción no válida."
  exit 1
  ;;
esac

echo ""
echo "======================================"
echo " Instalación completada. "
echo " Ahora abre en el navegador: http://tu-servidor "
echo "======================================"
