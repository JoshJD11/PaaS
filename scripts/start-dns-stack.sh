#!/bin/bash
# ─────────────────────────────────────────────────────────
# start-dns-stack.sh
# Levanta el stack de Docker Compose y valida que el DNS
# (BIND9) esté respondiendo correctamente.
#
# Uso:
#   chmod +x start-dns-stack.sh
#   ./start-dns-stack.sh
# ─────────────────────────────────────────────────────────

set -e

DOMAIN="paas.tec.cr"
WWW_HOST="www.paas.tec.cr"
DNS_HOST_PORT="5300"   # puerto mapeado en docker-compose.yml (5300:53)

echo "=========================================="
echo " PaaS - Levantando stack Docker Compose"
echo "=========================================="

# Verifica que docker compose esté disponible
if ! command -v docker &> /dev/null; then
    echo "[ERROR] Docker no está instalado o no está en el PATH."
    exit 1
fi

# Levanta los contenedores
echo ""
echo "[1/4] Levantando contenedores..."
docker compose up -d

# Espera unos segundos a que BIND9 termine de inicializar
echo ""
echo "[2/4] Esperando a que los servicios inicien (10s)..."
sleep 10

# Muestra estado de los contenedores
echo ""
echo "[3/4] Estado de los contenedores:"
docker compose ps

# Valida resolución DNS
echo ""
echo "[4/4] Validando resolución DNS..."
echo ""

if command -v dig &> /dev/null; then
    echo "--- Prueba con dig (puerto $DNS_HOST_PORT) ---"
    dig @127.0.0.1 -p "$DNS_HOST_PORT" "$DOMAIN" +short
    dig @127.0.0.1 -p "$DNS_HOST_PORT" "$WWW_HOST" +short
elif command -v nslookup &> /dev/null; then
    echo "--- Prueba con nslookup ---"
    nslookup -port="$DNS_HOST_PORT" "$DOMAIN" 127.0.0.1
else
    echo "[AVISO] No se encontró 'dig' ni 'nslookup' instalado."
    echo "Instala dnsutils con: sudo apt install dnsutils -y"
fi

# Validación interna (dentro de la red de Docker)
echo ""
echo "--- Prueba interna desde el contenedor wordpress ---"
docker compose exec -T wordpress getent hosts "$DOMAIN" || \
    echo "[AVISO] No se pudo validar desde el contenedor wordpress."

echo ""
echo "=========================================="
echo " Listo. Si ves una IP arriba (ej. 172.20.0.4),"
echo " el DNS está funcionando correctamente."
echo "=========================================="
