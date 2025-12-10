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

cert_digital_usuario() {
  read -p "[!] Nombre del directorio del sitio web del usuario: " DIR_USR
  if mkdir -p /etc/ssl/${DIR_USR}; then
    echo "[+] Directorio del sitio web del usuario creado con éxito en '/etc/ssl/${DIR_USR}'"
  else
    echo "[!!] Error al crear directorio del sitio web del usuario"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  cp openssl.plantilla openssl.cnf

  sed -i "s/DIR_ENTI_CERT/\/etc\/ssl\/${DIR_USR}/" openssl.cnf
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

  if mv openssl.cnf /etc/ssl/${DIR_USR}; then
    echo "[+] Fichero openssl modificado con éxito en '/etc/ssl/${DIR_USR}'"
  else
    echo "[!!] Hubo un error al modificar el archivo openssl.cnf"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  echo -e "\n[*] Generando claves para el usuario"
  read -p "Nombre de las claves (ej. ClavesCertificadoCliente): " NOM_CLAVE
  read -p "Contraseña o clave para el servidor (ej. ClaveCliente1234): " PASS_USR
  OPENSSL_CONF=/etc/ssl/${DIR_USR}/openssl.cnf openssl genrsa -des3 -out /etc/ssl/${DIR_USR}/${NOM_CLAVE}.pem -passout pass:${PASS_USR} 4096

  ret=$?
  if [[ $ret -ne 0 ]]; then
    echo "[!!] Error al generar las claves. Código: $ret"
  else
    echo "[+] Claves generadas correctamente"
  fi

  echo -e "\n[*] Creando la Solicitud de Firma de Certificado Digital (CSR) para el usuario"
  read -p "Nombre de la soliticitud (ej. SolicitudCertificadoCliente): " NOM_SOL
  openssl req -new -key /etc/ssl/${DIR_URS}/${NOM_CLAVE}.pem \
    -passin pass:${PASS_URS} \
    -out /etc/ssl/${DIR_URS}/${NOM_SOL}.pem \
    -config /etc/ssl/${DIR_URS}/openssl.cnf

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

  cat <<EOF >/etc/ssl/${DIR_ENT}/CertClientConf
basicConstraints = critical,CA:FALSE
extendedKeyUsage = serverAuth
EOF

  echo "[+] Archivo CertClientCOnf creado correctamente"

  echo "[*] Firmando la solicitud"
  read -p "Nombre del certificado existente (ej. CertificadoAC): " NOM_CERTIFICADO
  read -p "Nombre de las claves (j. ClavesAC): " NOM_CLAVE
  read -p "Nombre del directorio del usuario: " DIR_USR
  read -p "Nombre de la soliticitud (ej. SolicitudCertificadoCliente): " NOM_SOL
  read -p "Nombre del certificado de la solicitud (ej. CertificadoCliente): " NOM_CERT_SOL
  openssl x509 -CA /etc/ssl/${DIR_ENT}/${NOM_CERTIFICADO}.pem \
    -CAkey /etc/ssl/${DIR_ENT}/${NOM_CLAVE}.pem \
    -req -in /etc/ssl/${DIR_USR}/${NOM_SOL}.pem \
    -days 3650 \
    -extfile /etc/ssl/${DIR_ENT}/CertClientConf \
    -sha256 -CAcreateserial \
    -out /etc/ssl/${DIR_USR}/${NOM_CERT_SOL}.pem

  ret=$?
  if [[ $ret -ne 0 ]]; then
    echo "[!!] Error al generar el certificado de la solicitud. Código: $ret"
  else
    echo "[+] Certificado generado correctamente"
  fi
}

clave_p12() {
  read -p "[!] Nombre del directorio del sitio web del servidor: " DIR_USR
  if mkdir -p /etc/ssl/${DIR_USR}; then
    echo "[+] Directorio del sitio web del servidor creado con éxito en '/etc/ssl/${DIR_USR}'"
  else
    echo "[!!] Error al crear directorio del sitio web del servidor"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  read -p "Nombre de las claves (ej. ClavesCertificadoCliente): " NOM_CLAVE
  read -p "Nombre del certificado de la solicitud (ej. CertificadoCliente): " NOM_CERT_SOL
  read -p "Contraseña o clave para el servidor (ej. ClaveCliente1234): " PASS_USR
  read -p "[!] Nombre del directorio de la Entidad Certificadora: " DIR_ENT
  read -p "Nombre del certificado (ej. CertificadoAC): " NOM_CERTIFICADO
  openssl pkcs12 -export -in /etc/ssl/${DIR_USR}/${NOM_CERT_SOL}.pem \
    -inkey /etc/ssl/${DIR_USR}/${NOM_CLAVE}.pem \
    -certfile /etc/ssl/${DIR_ENT}/${NOM_CERTIFICADO}.pem \
    -out /etc/ssl/${DIR_USR}/CertificadoCliente.p12 \
    -passin pass:${PASS_USR} \
    -passout pass:${PASS_USR}

  ret=$?
  if [[ $ret -ne 0 ]]; then
    echo "[!!] Error al generar el certificado de la solicitud. Código: $ret"
  else
    echo "[+] Certificado generado correctamente (CertificadoCliente.p12)"
  fi

  read -p "Nombre del fichero de configuración sitio web existente (ej. wordpress.conf): " NOM_WEB_CONF
  if [[ ! -e /etc/apache2/sites-available/${NOM_WEB_CONF} ]]; then
    echo "[!!] No se encuentra el fichero de configuración del sitio web"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  sed -i '$d' /etc/apache2/sites-available/${NOM_WEB_CONF}

  echo -e "\tSSLCACertificateFile /etc/ssl/${DIR_ENT}/${NOM_CERTIFICADO}.pem" >>/etc/apache2/sites-available/${NOM_WEB_CONF}
  echo -e "\tSSLVerifyClient require" >>/etc/apache2/sites-available/${NOM_WEB_CONF}
  echo -e "</VirtualHost>" >>/etc/apache2/sites-available/${NOM_WEB_CONF}

  echo -e "\n[+] Reiniciando servicio apache"

  systemctl restart apache2.service
}

automatizar() {
  read -p "Nombre del directorio del sitio web del servidor: " DIR_SRV
  read -p "Contraseña o clave para el servidor (ej. ClaveServidor1234): " PASS_SRV

  echo "#!/bin/bash" >>/etc/ssl/${DIR_SRV}/claveweb.sh
  echo "${PASS_SRV}" >>/etc/ssl/${DIR_SRV}/claveweb.sh

  read -p "Nombre del fichero de configuración sitio web existente (ej. wordpress.conf): " NOM_WEB_CONF
  if [[ ! -e /etc/apache2/sites-available/${NOM_WEB_CONF} ]]; then
    echo "[!!] No se encuentra el fichero de configuración del sitio web"
    echo -e "[!!] Abortando...\n"
    exit 1
  fi

  echo -e "\tSSLPassPhrasedialog exec:/etc/ssl/${DIR_SRV}/claveweb.sh" >>/etc/apache2/sites-available/${NOM_WEB_CONF}

  echo -e "\n[*] Automatización creada con éxito"
}

clear
while true; do
  clear
  echo "1. Crear Certificado Digital para el Usuario"
  echo "2. Emitir un Certificado para el Usuario"
  echo "3. Obtener clave .p12"
  echo "4. Automatizar el reinicio de Apache"
  read -p "Opcion: " opt

  case "$opt" in
  1)
    echo "[*] Creando Certificado Digital para el usuario..."
    cert_digital_usuario
    ;;
  2)
    echo "[*] Emitiendo un certificado para un servidor..."
    emitir_cert
    ;;
  3)
    echo "[*] Convirtiendo .pem a .p12 ..."
    clave_p12
    ;;
  4)
    echo "[*] Automatizando el reinicio de Apache..."
    automatizar
    ;;
  4)
    exit 0
    ;;
  *)
    echo "Opción inválida. Saliendo..."
    exit 1
    ;;
  esac
  read -p "Pulsa intro para continuar ..." intro
done
