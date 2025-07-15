#!/bin/bash
set -euxo pipefail # set -e: salir en error, set -u: variables no definidas, set -x: depuración, set -o pipefail: error en pipelines

# Uso: ./run-retroarch <sistema> <nombre_juego>
SISTEMA="$1"
JUEGO="$2"

if [ -z "$SISTEMA" ] || [ -z "$JUEGO" ]; then
  echo "Uso: $0 <sistema> <nombre_juego>"
  exit 1
fi

# Configuración de directorios para el proyecto HIVE
# Estos directorios son relativos a donde se ejecuta el script (que será la raíz de tu proyecto Electron)
BASE_LIST_URL="https://raw.githubusercontent.com/Valchrist23/Vic/master/games"
ROMS_DIR="$(pwd)/roms"
SYSTEM_BIOS_DIR="$(pwd)/system_bios" # Donde se guardan las BIOS permanentes
SYSTEM_DIR="$(pwd)/system"           # Directorio temporal para BIOS que RetroArch usa

declare -A CORES=(
  ["nes"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/nestopia_libretro.so"
  ["snes"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/snes9x_libretro.so"
  ["ps1"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/swanstation_libretro.so"
  ["ps2"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/pcsx2_libretro.so"
  ["dreamcast"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/flycast_libretro.so"
  ["n64"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/mupen64plus_next_libretro.so"
  ["gba"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/mgba_libretro.so"
  ["genesis"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/picodrive_libretro.so"
  ["segacd"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/picodrive_libretro.so"
  ["ds"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/melondsds_libretro.so"
  ["gb"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/tgbdual_libretro.so"
  ["gbc"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/tgbdual_libretro.so"
  ["dos"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/dosbox_pure_libretro.so"
  ["gamecube"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/dolphin_libretro.so"
  ["psp"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/ppsspp_libretro.so"
  ["pce"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/mednafen_pce_libretro.so"
  ["pcecd"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/mednafen_pce_libretro.so"
  ["msx"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/fmsx_libretro.so"
  ["fbneo"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/fbneo_libretro.so"
  ["pc98"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/nekop2_libretro.so"
  ["saturn"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/yabasanshiro_libretro.so"
  ["mame"]="/home/val/.var/app/org.libretro.RetroArch/config/retroarch/cores/mame_libretro.so"
)

# Función para ejecutar RetroArch vía Flatpak
retroarch_run() {
  # $1 es el core, $2 es el ARCHIVO_ROM
  flatpak run \
    --filesystem="${ROMS_DIR}" \
    --filesystem="${SYSTEM_DIR}" \
    --filesystem="${SYSTEM_BIOS_DIR}" \
    org.libretro.RetroArch -L "$1" "$2" --fullscreen
}

# Crear carpetas necesarias
mkdir -p "${ROMS_DIR}/${SISTEMA}"
mkdir -p "${SYSTEM_BIOS_DIR}/${SISTEMA}"
mkdir -p "${SYSTEM_DIR}"

# Descargar lista de juegos
LIST_URL="${BASE_LIST_URL}/${SISTEMA}.txt"
echo "Descargando lista de juegos desde: ${LIST_URL}"
ROM_LIST=$(curl -s "${LIST_URL}" | tr -d '\r' | sed 's/ / /g') # quita retorno de carro y reemplaza espacios duros
if [ -z "${ROM_LIST}" ]; then
  echo "ERROR: No se pudo descargar la lista para '${SISTEMA}'"
  exit 1
fi

# Limpiar nombre del juego: quitar (USA), [!], etc., pasar a minúsculas
JUEGO_LIMPIO=$(echo "${JUEGO}" | tr -d '\r' | sed -E 's/\[[^]]*\]//g; s/\([^)]*\)//g; s/^[[:space:]]*//; s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')

# Buscar línea coincidente (match exacto, ignorando mayúsculas y espacios duros)
LINEA=$(echo "${ROM_LIST}" | awk -F"|" -v juego="${JUEGO_LIMPIO}" '
{
  titulo = tolower($1)
  gsub(/^[ \t]+|[ \t]+$/, "", titulo)
  if (titulo == juego) {
    print $0
    found = 1
    exit
  }
}
END {
  if (!found) print ""
}')

# Fallback: búsqueda parcial si no hubo match exacto
if [ -z "${LINEA}" ]; then
  echo "DEBUG: No se encontró match exacto, intentando búsqueda parcial..."
  LINEA=$(echo "${ROM_LIST}" | awk -F"|" -v juego="${JUEGO_LIMPIO}" '
  {
    titulo = tolower($1)
    gsub(/^[ \t]+|[ \t]+$/, "", titulo)
    if (index(titulo, juego)) {
      print $0
      exit
    }
  }')
fi

# Mostrar debug detallado
echo "DEBUG: Juego buscado = [${JUEGO_LIMPIO}]"
echo "Línea completa encontrada: [${LINEA}]"
echo "${LINEA}" | awk -F"|" '{for(i=1;i<=NF;i++) print "Campo " i ": [" $i "]"}'

# Verificar si se encontró algo
if [ -z "${LINEA}" ]; then
  echo "❌ ERROR: Juego '${JUEGO}' no encontrado para '${SISTEMA}' en la lista remota."
  exit 1
fi

# Extraer URL del juego
echo "🧪 LINEA: [${LINEA}]"
URL=$(echo "${LINEA}" | cut -d'|' -f2 | tr -d '\r')
echo "🌐 URL extraída: [${URL}]"

if [ -z "${URL}" ]; then
  echo "❌ ERROR: No se pudo extraer una URL válida de la línea: [${LINEA}]"
  exit 1
fi

# Determinar el nombre del archivo local a partir de la URL (maneja espacios y caracteres especiales)
URL_BASENAME=$(basename "${URL}")
FILENAME_DECODED=$(printf '%b' "${URL_BASENAME//%/\\x}")
ARCHIVO_ROM="${ROMS_DIR}/${SISTEMA}/${FILENAME_DECODED}"

# Descargar ROM si no existe o está vacía
if [ ! -f "${ARCHIVO_ROM}" ] || [ ! -s "${ARCHIVO_ROM}" ]; then
  echo "Descargando '${JUEGO}' a '${ARCHIVO_ROM}'..."

  # Muestra la progressbar y maneja errores de wget
  wget --progress=bar:force -O "${ARCHIVO_ROM}" "${URL}"
  if [ $? -ne 0 ]; then
      echo "❌ ERROR: No se pudo descargar la ROM '${JUEGO}'. Código de salida: $?."
      # Limpia el archivo incompleto/vacío si la descarga falla
      if [ -f "${ARCHIVO_ROM}" ] && [ ! -s "${ARCHIVO_ROM}" ]; then
          rm -f "${ARCHIVO_ROM}"
      fi
      exit 1
  fi
  echo "Descarga de '${JUEGO}' completa."
fi

# Descargar lista BIOS
BIOS_LIST_URL="https://raw.githubusercontent.com/Valchrist23/Vic/master/system/system.txt"
echo "Descargando lista de BIOS desde: ${BIOS_LIST_URL}"
BIOS_LIST=$(curl -s "${BIOS_LIST_URL}")

if [ -z "${BIOS_LIST}" ]; then
    echo "ADVERTENCIA: No se pudo obtener la lista de BIOS de GitHub. Las BIOS pueden faltar."
fi

# Descargar BIOS permanentes (solo si no existen)
echo "Verificando y descargando BIOS permanentes en '${SYSTEM_BIOS_DIR}'..."
while IFS="|" read -r REL_PATH BIOS_URL; do
  if [[ "${REL_PATH}" == "${SISTEMA}/"* ]]; then
    DEST="${SYSTEM_BIOS_DIR}/${REL_PATH}"
    mkdir -p "$(dirname "${DEST}")" # Asegura que el subdirectorio exista
    if [ ! -f "${DEST}" ]; then
      echo "Descargando BIOS: ${REL_PATH}"
      wget --continue --tries=3 --timeout=30 -O "${DEST}" "${BIOS_URL}"
      if [ $? -ne 0 ]; then
          echo "ADVERTENCIA: Falló la descarga de ${BIOS_URL} a ${DEST}"
      fi
    fi
  fi
done <<< "${BIOS_LIST}"

# Preparar BIOS temporales (RetroArch no lee subcarpetas, por eso se copian a SYSTEM_DIR)
echo "Preparando BIOS temporales en '${SYSTEM_DIR}'..."
rm -rf "${SYSTEM_DIR}"/* # <--- CORRECCIÓN: rm -rf para directorios

while IFS="|" read -r REL_PATH BIOS_URL; do
  if [[ "${REL_PATH}" == "${SISTEMA}/"* ]]; then
    BIOS_FILENAME=$(basename "${REL_PATH}")
    PERM_BIOS="${SYSTEM_BIOS_DIR}/${REL_PATH}"
    TEMP_BIOS="${SYSTEM_DIR}/${BIOS_FILENAME}"
    if [ -f "${PERM_BIOS}" ]; then
      cp "${PERM_BIOS}" "${TEMP_BIOS}"
    else
      echo "ADVERTENCIA: BIOS permanente no encontrada para copiar: ${PERM_BIOS}. El juego podría no funcionar correctamente."
    fi
  fi
done <<< "${BIOS_LIST}"

# Verificar que la ROM exista y no esté vacía antes de lanzar
echo "Verificando archivo ROM: ${ARCHIVO_ROM}"
if [ ! -f "${ARCHIVO_ROM}" ]; then
  echo "ERROR: El archivo ROM no existe en la ruta especificada: ${ARCHIVO_ROM}"
  exit 1
fi
if [ ! -s "${ARCHIVO_ROM}" ]; then
  echo "ERROR: El archivo ROM está vacío: ${ARCHIVO_ROM}"
  exit 1
fi

# Verificar core
CORE=${CORES[$SISTEMA]}
echo "Core para el sistema '${SISTEMA}': ${CORE}"
if [ -z "${CORE}" ] || [ ! -f "${CORE}" ]; then
  echo "ERROR: No se encontró el core para el sistema '${SISTEMA}' o la ruta del core es incorrecta: ${CORE}"
  exit 1
fi

# Guarda la última ROM lanzada (opcional, para depuración o uso posterior)
echo "${ARCHIVO_ROM}" > /tmp/last-rom.txt

echo "Lanzando RetroArch con ROM: '${ARCHIVO_ROM}' y Core: '${CORE}'"

# --- Ejecución de RetroArch ---
retroarch_run "${CORE}" "${ARCHIVO_ROM}"

# Verificar el código de salida de RetroArch
if [ $? -ne 0 ]; then
    echo "RetroArch terminó con un error. Código de salida: $?."
    echo "Asegúrate de que RetroArch y el core estén instalados correctamente y tengan los permisos adecuados."
    exit 1
fi

# --- Limpieza al finalizar ---
# Solo preguntar si está en terminal interactiva
if [ -t 1 ]; then # Verifica si el script se ejecuta en una terminal interactiva
    read -p "¿Quieres borrar la ROM descargada? (s/n): " BORRAR
    if [ "${BORRAR}" = "s" ]; then
        echo "Borrando ROM: ${ARCHIVO_ROM}"
        rm -f "${ARCHIVO_ROM}"
    fi
fi
# Limpiar BIOS temporales finales
echo "Limpiando BIOS temporales finales..."
rm -rf "${SYSTEM_DIR}"/* # <--- CORRECCIÓN: rm -rf para directorios

echo "Script run-retroarch finalizado."
exit 0
