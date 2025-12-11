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

cert_digital_servidor() {
  read -p "[!] Nombre del directorio para el certificado de usuario: " DIR_SRV
  if mkdir -p /etc/ssl/${DIR_SRV}; then
    echo "[+] Directorio del usuario creado con éxito en '/etc/ssl/${DIR_SRV}'"
  else
    echo "[!!] Error al crear directorio del usuario"
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
  read -p "[!] Nombre de la organización (O): " NOM_ENT_CERT
  sed -i "s/NOMBRE_ENTIDAD_CERTIFICADORA/${NOM_ENT_CERT}/" openssl.cnf
  read -p "[!] Nombre de la unidad organizativa o departamento (OU): " NOM_DPTO
  sed -i "s/NOMBRE_UNIDAD_DPTO/${NOM_DPTO}/" openssl.cnf
  read -p "[!] Nombre común (el que va a aparecer en el certificado): " NOM_COMUN
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

  echo -e "\n[*] Generando claves para el usuario"
  read -p "Nombre de las claves [ClavesCertificadoUsuario]: " NOM_CLAVE
  NOM_CLAVE=${NOM_CLAVE:-ClavesCertificadoUsuario}
  read -p "Contraseña o clave del usuario [Clave1234]: " PASS_SRV
  PASS_SRV=${PASS_SRV:-Clave1234}
  OPENSSL_CONF=/etc/ssl/${DIR_SRV}/openssl.cnf openssl genrsa -des3 -out /etc/ssl/${DIR_SRV}/${NOM_CLAVE}.pem -passout pass:${PASS_SRV} 4096

  ret=$?
  if [[ $ret -ne 0 ]]; then
    echo "[!!] Error al generar las claves. Código: $ret"
  else
    echo "[+] Claves generadas correctamente"
  fi

  echo -e "\n[*] Creando la Solicitud de Firma de Certificado Digital (CSR) para el Usuario"
  read -p "Nombre de la soliticitud (ej. [SolicitudCertificadoUsuario}: " NOM_SOL
  NOM_SOL=${NOM_SOL:-SolicitudCertificadoUsuario}
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

  cat <<EOF >/etc/ssl/${DIR_ENT}/CertClientConf
basicConstraints = critical,CA:FALSE
extendedKeyUsage = clientAuth
EOF

  echo "[+] Archivo CertClientConf creado correctamente"

  echo "[*] Firmando la solicitud"
  read -p "Nombre del certificado existente ej. [CertificadoAC]: " NOM_CERTIFICADO
  NOM_CERTIFICADO=${NOM_CERTIFICADO:-CertificadoAC}
  read -p "Nombre de las claves ej. [ClavesAC]: " NOM_CLAVE
  NOM_CLAVE=${NOM_CLAVE:-ClavesAC}
  read -p "Nombre del directorio del certificado de usuario: " DIR_SRV
  read -p "Nombre de la soliticitud ej. [SolicitudCertificadoUsuario]: " NOM_SOL
  NOM_SOL=${NOM_SOL:-SolicitudCertificadoUsuario}
  read -p "Nombre del certificado de la solicitud ej. [CertificadoUsuario]: " NOM_CERT_SOL
  NOM_CERT_SOL=${NOM_CERT_SOL:-CertificadoUsuario}
  read -p "Nombre de las claves del usuario ej [ClavesCertificadoUsuario]: " NOM_CLAVE_USER
  NOM_CLAVE_USER=${NOM_CLAVE_USER:-ClavesCertificadoUsuario}
  read -p "Contraseña o clave del usuario ej. [Clave1234]: " PASS_SRV
  PASS_SRV=${PASS_SRV:-Clave1234}
  read -p "Contraseña del certificado del servidor web ej [Clave1234]: " PASS_WEB
  PASS_WEB=${PASS_WEB:-Clave1234}
  openssl x509 -CA /etc/ssl/${DIR_ENT}/${NOM_CERTIFICADO}.pem \
    -CAkey /etc/ssl/${DIR_ENT}/${NOM_CLAVE}.pem \
    -req -in /etc/ssl/${DIR_SRV}/${NOM_SOL}.pem \
    -days 3650 \
    -extfile /etc/ssl/${DIR_ENT}/CertClientConf \
    -sha256 -CAcreateserial \
    -out /etc/ssl/${DIR_SRV}/${NOM_CERT_SOL}.pem
  openssl pkcs12 -export -in /etc/ssl/${DIR_SRV}/${NOM_CERT_SOL}.pem \
    -inkey /etc/ssl/${DIR_SRV}/${NOM_CLAVE_USER}.pem \
    -certfile /etc/ssl/${DIR_ENT}/${NOM_CERTIFICADO}.pem \
    -out /etc/ssl/${DIR_SRV}/${NOM_CERT_SOL}.p12 -passin pass:${PASS_SRV} -passout pass:${PASS_SRV}
  chmod 777 /etc/ssl/${DIR_SRV}/${NOM_CERT_SOL}.p12
  read -p "Dime el nombre del archivo de configuracion de la web ej [wordpress.conf]: " WORD_CONF
  WORD_CONF=${WORD_CONF:-wordpress.conf}
  comprobar=$(tail -1 /etc/apache2/sites-available/${WORD_CONF} | cut -f2-)
  if [[ "$comprobar" != "SSLPassPhraseDialog exec:/etc/ssl/mifrase.sh" ]]; then

    sed -i '$d' /etc/apache2/sites-available/${WORD_CONF}
    echo -e "\tSSLCACertificateFile /etc/ssl/${DIR_ENT}/${NOM_CERTIFICADO}.pem" >>/etc/apache2/sites-available/${WORD_CONF}
    echo -e "\tSSLVerifyClient require" >>/etc/apache2/sites-available/${WORD_CONF}
    echo -e "</VirtualHost>" >>/etc/apache2/sites-available/${WORD_CONF}
    read -p "Nombre de la carpeta del certificado de la web: " DIR_WEB
    echo -e "#!/bin/bash\n echo ${PASS_WEB}" >/etc/ssl/${DIR_WEB}/mifrase.sh
    echo -e "\tSSLPassPhraseDialog exec:/etc/ssl/${DIR_WEB}/mifrase.sh" >>/etc/apache2/sites-available/${WORD_CONF}
    chmod 755 /etc/ssl/${DIR_WEB}/mifrase.sh
    systemctl restart apache2
  fi
  ret=$?
  if [[ $ret -ne 0 ]]; then
    echo "[!!] Error al generar el certificado de la solicitud. Código: $ret"
  else
    echo "[+] Certificado generado correctamente"
  fi

}

clear
while true; do
  clear
  echo "1. Crear Certificado Digital para Usuario"
  echo "2. Firmar y exportar certificado de usuario a p12"
  echo "3. Salir"
  read -p "Opcion: " opt

  case "$opt" in
  1)
    echo "[*] Creando Certificado Digital para el usuario..."
    cert_digital_servidor
    ;;
  2)
    echo "[*] Emitiendo un certificado para un usuario..."
    emitir_cert
    ;;
  3)
    exit 0
    ;;
  *)
    echo "Opción inválida. Saliendo..."
    exit 1
    ;;
  esac
  read -p "Pulsa intro para continuar ..." intro
done
