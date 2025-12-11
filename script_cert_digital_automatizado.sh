#!/usr/bin/env bash

# Verificación de usuario root
if [ "$(whoami)" != "root" ]; then
  echo "Debes ejecutar este script como root o usando sudo."
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "[?] No tienes instalado openssl..."
  echo "[*] Instalando openssl"
  apt install -y openssl
  read -p "Pulsa intro para continuar ..." continuar
fi

entidad_certificadora() {
  read -p "[!] Nombre del directorio de la Entidad Certificadora: " DIR_ENT
  if mkdir -p /etc/ssl/${DIR_ENT}; then
    echo "[+] Directorio de la entidad certificadora creado con éxito en '/etc/ssl/${DIR_ENT}'"
  else
    echo "[!!] Error al crear directorio de la entidad certificadora"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  cp openssl.plantilla openssl.cnf

  sed -i "s/DIR_ENTI_CERT/\/etc\/ssl\/${DIR_ENT}/" openssl.cnf
  read -p "[!] Iniciales del pais: " INI_PAIS
  sed -i "s/INICIALES_PAIS/${INI_PAIS}/" openssl.cnf
  read -p "[!] Nombre del estado o provincia: " NOM_PROV
  sed -i "s/NOMBRE_PROVINCIA/${NOM_PROV}/" openssl.cnf
  read -p "[!] Nombre de la localidad: " NOM_LOCA
  sed -i "s/NOMBRE_LOCALIDAD/${NOM_LOCA}/" openssl.cnf
  read -p "[!] Nombre de la entidad certificadora: " NOM_ENT_CERT
  sed -i "s/NOMBRE_ENTIDAD_CERTIFICADORA/${NOM_ENT_CERT}/" openssl.cnf
  read -p "[!] Nombre de la unidad organizativa o departamento: " NOM_DPTO
  sed -i "s/NOMBRE_UNIDAD_DPTO/${NOM_DPTO}/" openssl.cnf
  read -p "[!] Nombre común: " NOM_COMUN
  sed -i "s/NOMBRE_COMUN/${NOM_COMUN}/" openssl.cnf
  read -p "[!] Correo electrónico: " NOM_EMAIL
  sed -i "s/DIR_EMAIL/${NOM_EMAIL}/" openssl.cnf

  if mv openssl.cnf /etc/ssl/${DIR_ENT}; then
    echo "[+] Fichero openssl modificado con éxito en '/etc/ssl/${DIR_ENT}'"
  else
    echo "[!!] Hubo un error al modificar el archivo openssl.cnf"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  echo -e "\n[*] Generando el par de claves para la entidad certificadora"
  read -p "Nombre de las claves ej. [ClavesAC]: " NOM_CLAVE
  NOM_CLAVE=${NOM_CLAVE:-ClavesAC}
  read -p "Nombre del certificado ej. [CertificadoAC]: " NOM_CERTIFICADO
  NOM_CERTIFICADO=${NOM_CERTIFICADO:-CertificadoAC}
  read -p "Contraseña o clave de la AC ej. [Clave1234]: " PASS_AC
  PASS_AC=${PASS_AC:-Clave1234}
  openssl req -x509 -newkey rsa:4096 \
    -keyout /etc/ssl/${DIR_ENT}/${NOM_CLAVE}.pem \
    -days 3650 \
    -out /etc/ssl/${DIR_ENT}/${NOM_CERTIFICADO}.pem \
    -passout pass:${PASS_AC} \
    -config /etc/ssl/${DIR_ENT}/openssl.cnf

  ret=$?
  if [[ $ret -ne 0 ]]; then
    echo "[!!] Error al generar las claves. Código: $ret"
  else
    echo "[+] Claves generadas correctamente"
  fi
}

cert_digital_servidor() {
  read -p "[!] Nombre del directorio del sitio web del servidor: " DIR_SRV
  if mkdir -p /etc/ssl/${DIR_SRV}; then
    echo "[+] Directorio del sitio web del servidor creado con éxito en '/etc/ssl/${DIR_SRV}'"
  else
    echo "[!!] Error al crear directorio del sitio web del servidor"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  cp openssl.plantilla openssl.cnf

  sed -i "s/DIR_ENTI_CERT/\/etc\/ssl\/${DIR_SRV}/" openssl.cnf
  read -p "[!] Iniciales del pais: " INI_PAIS
  sed -i "s/INICIALES_PAIS/${INI_PAIS}/" openssl.cnf
  read -p "[!] Nombre del estado o provincia: " NOM_PROV
  sed -i "s/NOMBRE_PROVINCIA/${NOM_PROV}/" openssl.cnf
  read -p "[!] Nombre de la localidad: " NOM_LOCA
  sed -i "s/NOMBRE_LOCALIDAD/${NOM_LOCA}/" openssl.cnf
  read -p "[!] Nombre de la entidad certificadora: " NOM_ENT_CERT
  sed -i "s/NOMBRE_ENTIDAD_CERTIFICADORA/${NOM_ENT_CERT}/" openssl.cnf
  read -p "[!] Nombre de la unidad organizativa o departamento: " NOM_DPTO
  sed -i "s/NOMBRE_UNIDAD_DPTO/${NOM_DPTO}/" openssl.cnf
  read -p "[!] Nombre común ([!] Debe ser igual al FQDN de la web): " NOM_COMUN
  sed -i "s/NOMBRE_COMUN/${NOM_COMUN}/" openssl.cnf
  read -p "[!] Correo electrónico: " NOM_EMAIL
  sed -i "s/DIR_EMAIL/${NOM_EMAIL}/" openssl.cnf

  if mv openssl.cnf /etc/ssl/${DIR_SRV}; then
    echo "[+] Fichero openssl modificado con éxito en '/etc/ssl/${DIR_SRV}'"
  else
    echo "[!!] Hubo un error al modificar el archivo openssl.cnf"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  echo -e "\n[*] Generando claves para el servidor"
  read -p "Nombre de las claves ej. [ClavesCertificadoServidor]: " NOM_CLAVE
  NOM_CLAVE=${NOM_CLAVE:-ClavesCertificadoServidor}
  read -p "Contraseña o clave para el servidor ej. [Clave1234]: " PASS_SRV
  PASS_SRV=${PASS_SRV:-Clave1234}
  OPENSSL_CONF=/etc/ssl/${DIR_SRV}/openssl.cnf openssl genrsa -des3 -out /etc/ssl/${DIR_SRV}/${NOM_CLAVE}.pem -passout pass:${PASS_SRV} 4096

  ret=$?
  if [[ $ret -ne 0 ]]; then
    echo "[!!] Error al generar las claves. Código: $ret"
  else
    echo "[+] Claves generadas correctamente"
  fi

  echo -e "\n[*] Creando la Solicitud de Firma de Certificado Digital (CSR) para el servidor"
  read -p "Nombre de la soliticitud ej. [SolicitudCertificadoServidor]: " NOM_SOL
  NOM_SOL=${NOM_SOL:-SolicitudCertificadoServidor}
  openssl req -new -key /etc/ssl/${DIR_SRV}/${NOM_CLAVE}.pem \
    -passin pass:${PASS_SRV} \
    -out /etc/ssl/${DIR_SRV}/${NOM_SOL}.pem \
    -config /etc/ssl/${DIR_SRV}/openssl.cnf

  ret=$?
  if [[ $ret -ne 0 ]]; then
    echo "[!!] Error al generar la solicitud. Código: $ret"
  else
    echo "[+] Solicitud generada correctamente"
  fi
}

emitir_cert() {
  read -p "[!] Nombre del directorio de la Entidad Certificadora: " DIR_ENT
  if [[ ! -d /etc/ssl/${DIR_ENT} ]]; then
    echo "[!!] La entidad certificadora no existe. Créala antes"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  cat <<EOF >/etc/ssl/${DIR_ENT}/CertServerConf
basicConstraints = critical,CA:FALSE
extendedKeyUsage = serverAuth
EOF

  echo "[+] Archivo CertServerConf creado correctamente"

  echo "[*] Firmando la solicitud"
  read -p "Nombre del certificado existente ej. [CertificadoAC]: " NOM_CERTIFICADO
  NOM_CERTIFICADO=${NOM_CERTIFICADO:-CertificadoAC}
  read -p "Nombre de las claves ej. [ClavesAC]: " NOM_CLAVE
  NOM_CLAVE=${NOM_CLAVE:-ClavesAC}
  read -p "Nombre del directorio del sitio web del servidor: " DIR_SRV
  read -p "Nombre de la soliticitud ej. [SolicitudCertificadoServidor]: " NOM_SOL
  NOM_SOL=${NOM_SOL:-SolicitudCertificadoServidor}
  read -p "Nombre del certificado de la solicitud ej. [CertificadoServidor]: " NOM_CERT_SOL
  NOM_CERT_SOL=${NOM_CERT_SOL:-CertificadoServidor}
  openssl x509 -CA /etc/ssl/${DIR_ENT}/${NOM_CERTIFICADO}.pem \
    -CAkey /etc/ssl/${DIR_ENT}/${NOM_CLAVE}.pem \
    -req -in /etc/ssl/${DIR_SRV}/${NOM_SOL}.pem \
    -days 3650 \
    -extfile /etc/ssl/${DIR_ENT}/CertServerConf \
    -sha256 -CAcreateserial \
    -out /etc/ssl/${DIR_SRV}/${NOM_CERT_SOL}.pem

  ret=$?
  if [[ $ret -ne 0 ]]; then
    echo "[!!] Error al generar el certificado de la solicitud. Código: $ret"
  else
    echo "[+] Certificado generado correctamente"
  fi
}

ssl_apache2() {
  read -p "Nombre del fichero de configuración sitio web existente (ej. [wordpress.conf]: " NOM_WEB_CONF
  NOM_WEB_CONF=${NOM_WEB_CONF:-wordpress.conf}
  if [[ ! -e /etc/apache2/sites-available/${NOM_WEB_CONF} ]]; then
    echo "[!!] No se encuentra el fichero de configuración del sitio web"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  if ! grep -q ServerSignature /etc/apache2/sites-available/${NOM_WEB_CONF}; then
    read -p "Nombre del directorio del sitio web del servidor: " DIR_SRV
    read -p "Nombre del certificado de la solicitud ej. [CertificadoServidor]: " NOM_CERT_SOL
    NOM_CERT_SOL=${NOM_CERT_SOL:-CertificadoServidor}
    read -p "Nombre de las claves ej. [ClavesCertificadoServidor]: " NOM_CLAVE
    NOM_CLAVE=${NOM_CLAVE:-ClavesCertificadoServidor}

    # Falta por mejorar las indentaciones
    #  sed -i "/<\/VirtualHost>/i \
    sed -i '$d' /etc/apache2/sites-available/${NOM_WEB_CONF}

    echo -e "\tServerSignature On" >>/etc/apache2/sites-available/${NOM_WEB_CONF}
    echo -e "\tSSLEngine On" >>/etc/apache2/sites-available/${NOM_WEB_CONF}
    echo -e "\tSSLCertificateFile /etc/ssl/${DIR_SRV}/${NOM_CERT_SOL}.pem" >>/etc/apache2/sites-available/${NOM_WEB_CONF}
    echo -e "\tSSLCertificateKeyFile /etc/ssl/${DIR_SRV}/${NOM_CLAVE}.pem" >>/etc/apache2/sites-available/${NOM_WEB_CONF}
    echo -e "</VirtualHost>" >>/etc/apache2/sites-available/${NOM_WEB_CONF}
  fi

  read -p "[!] ¿Qué puerto HTTPS vas a usar (por defecto: 443)?: " PORT_SSL
  #sed -i 's/<VirtualHost \*: *[0-9]\+>/<VirtualHost *:${PORT_SSL}>/g' /etc/apache2/sites-available/${NOM_WEB_CONF}
  sed -i "s#^\(<VirtualHost \*:\)[0-9]\+#\1${PORT_SSL}#g" \
    /etc/apache2/sites-available/${NOM_WEB_CONF}

  a2enmod ssl
  sed -i "s/^([[:space:]]+Listen[[:space:]]+)[0-9]+/\1${PORT_SSL}/g" /etc/apache2/sites-available/${NOM_WEB_CONF}

  if [[ PORT_SSL -ne 443 ]]; then
    read -p "Escribe el FQDN completo de la web a la que le vas a poner el puerto ${PORT_SSL} (ej: web1.wordpress.local): " DOMAIN
    cd /var/www/wordpress
    wp option update siteurl "https://${DOMAIN}:${PUERTO}" --allow-root
    wp option update home "https://${DOMAIN}:${PUERTO}" --allow-root
  else
    cd /var/www/wordpress
    wp option update siteurl "https://${DOMAIN}" --allow-root
    wp option update home "https://${DOMAIN}" --allow-root
  fi

  a2ensite ${NOM_WEB_CONF}
  systemctl restart apache2.service

  echo "[+] Certificado generado correctamente"
}

clear
while true; do
  clear
  echo "1. Crear Entidad Certificadora (AC)"
  echo "2. Crear Certificado Digital para Servidor"
  echo "3. Emitir un Certificado"
  echo "4. Activar módulo SSL en Apache2"
  echo "5. Salir"
  read -p "Opcion: " opt

  case "$opt" in
  1)
    echo "[*] Creando Entidad Certificadora..."
    entidad_certificadora
    ;;
  2)
    echo "[*] Creando Certificado Digital para el servidor..."
    cert_digital_servidor
    ;;
  3)
    echo "[*] Emitiendo un certificado para un servidor..."
    emitir_cert
    ;;
  4)
    echo "[*] Activando módulo SSL en Apache2..."
    ssl_apache2
    ;;
  5)
    exit 0
    ;;
  *)
    echo "Opción inválida. Saliendo..."
    exit 1
    ;;
  esac
  read -p "Pulsa intro para continuar ..." intro
done
