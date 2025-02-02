#!/bin/bash

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Error: Este script debe ejecutarse como root."
    exit 1
fi

echo "🔄 Preparando el sistema..."

# Detectar el gestor de paquetes
if command -v apt-get &>/dev/null; then
    PACKAGE_MANAGER="apt-get"
elif command -v yum &>/dev/null; then
    PACKAGE_MANAGER="yum"
else
    echo "❌ Error: No se detectó un gestor de paquetes compatible (apt-get o yum)."
    exit 1
fi

# Verificar versión del kernel
KERNEL_VERSION=$(uname -r | awk -F. '{print $1*100+$2}')
if [[ $KERNEL_VERSION -lt 415 ]]; then
    echo "❌ Error: Se requiere un kernel 4.15 o superior. Por favor, actualiza tu sistema."
    exit 1
fi

# Instalar paquetes necesarios según el gestor de paquetes
echo "📦 Instalando dependencias..."
if [[ $PACKAGE_MANAGER == "apt-get" ]]; then
    apt-get update && apt-get -y install \
        build-essential \
        patchutils \
        linux-headers-$(uname -r) \
        git \
        libproc-processtable-perl

    # Deshabilitar actualizaciones automáticas para evitar conflictos
    systemctl disable apt-daily.service
    systemctl disable apt-daily.timer

elif [[ $PACKAGE_MANAGER == "yum" ]]; then
    yum -y groupinstall "Development Tools"
    yum -y install epel-release
    yum -y install \
        perl-core \
        perl-Proc-ProcessTable \
        perl-Digest-SHA \
        kernel-headers \
        kernel-devel \
        elfutils-libelf-devel

    # Parche necesario para algunas versiones del kernel
    sed -i '/vm_fault_t;/d' /usr/src/media_build/v4l/compat.h
    sed -i '/add v4.20_access_ok.patch/d' /usr/src/media_build/backports/backports.txt
fi

# Eliminar instalaciones previas
echo "🧹 Limpiando versiones antiguas..."
rm -rf /usr/src/media_build /usr/src/dvb-firmwares.tar.bz2

# Clonar el repositorio de media_build
echo "⬇️ Descargando los archivos necesarios..."
git clone https://github.com/tbsdtv/media_build.git /usr/src/media_build

# Descargar e instalar los firmwares
echo "📥 Instalando firmware..."
curl -L https://github.com/tbsdtv/media_build/releases/download/latest/dvb-firmwares.tar.bz2 | tar -jxf - -C /lib/firmware/

# Compilar e instalar los drivers
cd /usr/src/media_build || { echo "❌ Error: No se pudo acceder a /usr/src/media_build"; exit 1; }
echo "⚙️ Compilando los módulos..."
./build && make install

echo "✅ Instalación completada. 🔄 Reinicia el sistema para aplicar los cambios."

