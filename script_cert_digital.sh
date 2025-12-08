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

  sed -i "s/DIR_ENTI_CERT/\/etc\/ssl\/${DIR_ENT}" openssl.cnf
  read -p "[!] Iniciales del pais: " INI_PAIS
  sed -i "s/INICIALES_PAIS/${INI_PAIS}" openssl.cnf
  read -p "[!] Nombre del estado o provincia: " NOM_PROV
  sed -i "s/NOMBRE_PROVINCIA/${NOM_PROV}" openssl.cnf
  read -p "[!] Nombre de la localidad: " NOM_LOCA
  sed -i "s/NOMBRE_LOCALIDAD/${NOM_LOCA}" openssl.cnf
  read -p "[!] Nombre de la entidad certificadora: " NOM_ENT_CERT
  sed -i "s/NOMBRE_ENTIDAD_CERTIFICADORA/${NOM_ENT_CERT}" openssl.cnf
  read -p "[!] Nombre de la unidad organizativa o departamento: " NOM_DPTO
  sed -i "s/NOMBRE_UNIDAD_DPTO/${NOM_DPTO}" openssl.cnf
  read -p "[!] Nombre común: " NOM_COMUN
  sed -i "s/NOMBRE_COMUN/${NOM_COMUN}" openssl.cnf
  read -p "[!] Correo electrónico: " NOM_EMAIL
  sed -i "s/DIR_EMAIL/${NOM_EMAIL}" openssl.cnf

  if mv openssl.cnf /etc/ssl/${DIR_ENT}; then
    echo "[+] Fichero openssl modificado con éxito en '/etc/ssl/${DIR_ENT}"
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

clear
echo "1. Crear Entidad Certificadora (AC)"
read -p "Opcion: " opt

case "$opt" in
1)
  echo "[*] Creando Entidad Certificadora..."
  entidad_certificadora
  ;;
2)
  echo "Otra funcion..."
  ;;
*)
  echo "Opción inválida. Saliendo..."
  exit 1
  ;;
esac
