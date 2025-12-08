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
  read -p "Nombre de las claves (ej. ClavesAC): " NOM_CLAVE
  read -p "Nombre del certificado (ej. CertificadoAC): " NOM_CERTIFICADO
  read -p "Contraseña o clave de la AC (ej. ClaveAC1234): " PASS_AC
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
  read -p "Nombre de las claves (ej. ClavesCertificadoServidor): " NOM_CLAVE
  read -p "Contraseña o clave para el servidor (ej. ClaveServidor1234): " PASS_SRV
  OPENSSL=/etc/ssl/${DIR_SRV}/openssl.cnf openssl genrsa -des3 -out /etc/ssl/${DIR_SRV}/${NOM_CLAVE}.pem -passout pass:${PASS_SRV} 4096

  ret=$?
  if [[ $ret -ne 0 ]]; then
    echo "[!!] Error al generar las claves. Código: $ret"
  else
    echo "[+] Claves generadas correctamente"
  fi

  echo -e "\n[*] Creando la Solicitud de Firma de Certificado Digital (CSR) para el servidor"
  read -p "Nombre de la soliticitud (ej. SolicitudCertificadoServidor): " NOM_SOL
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
  read -p "Nombre del certificado existente (ej. CertificadoAC): " NOM_CERTIFICADO
  read -p "Nombre de las claves (ej. ClavesAC): " NOM_CLAVE
  read -p "Nombre del directorio del sitio web del servidor: " DIR_SRV
  read -p "Nombre de la soliticitud (ej. SolicitudCertificadoServidor): " NOM_SOL
  read -p "Nombre del certificado de la solicitud (ej. CertificadoServidor): " NOM_CERT_SOL
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
  read -p "Nombre del fichero de configuración sitio web existente (ej. wordpress.conf): " NOM_WEB_CONF
  if [[ ! -e /etc/apache2/sites-available/${NOM_WEB_CONF}.conf ]]; then
    echo "[!!] No se encuentra el fichero de configuración del sitio web"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  read -p "Nombre del directorio del sitio web del servidor: " DIR_SRV
  read -p "Nombre del certificado de la solicitud (ej. CertificadoServidor): " NOM_CERT_SOL
  read -p "Nombre de las claves (ej. ClavesCertificadoServidor): " NOM_CLAVE
  sed -i "/<\/VirtualHost>/i \
  ServerSignature On\n\
  SSLEngine On\n\
  SSLCertificateFile /etc/ssl/${DIR_SRV}/${NOM_CERT_SOL}.pem\n\
  SSLCertificateKeyFile /etc/ssl/${DIR_SRV}/${NOM_CLAVE}.pem\n\
  " "/etc/apache2/sites-available/${NOM_WEB_CONF}.conf"

  sed -i 's/<VirtualHost \*: *[0-9]\+>/<VirtualHost *:443>/g' /etc/apache2/sites-available/${NOM_WEB_CONF}.conf

  a2enmod ssl
  systemctl restart apache2.service

  echo "[+] Certificado generado correctamente"
}

clear
echo "1. Crear Entidad Certificadora (AC)"
echo "2. Crear Certificado Digital para Servidor"
echo "3. Emitir un Certificado"
echo "4. Activar módulo SSL en Apache2"
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
*)
  echo "Opción inválida. Saliendo..."
  exit 1
  ;;
esac
