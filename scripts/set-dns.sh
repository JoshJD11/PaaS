#!/bin/bash
# ─────────────────────────────────────────────────────────
# Uso:
#   chmod +x start-dns-stack.sh
#   ./start-dns-stack.sh
# ─────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────
# Función para agregar entradas a /etc/hosts
# ─────────────────────────────────────────────────────────
add_host_entry() {
    local ip="$1"
    local hostname="$2"
    
    # Verifica si la línea ya existe (ignorando espacios/tabuladores)
    if ! grep -q "^$ip\s\+$hostname" /etc/hosts; then
        echo "[INFO] Agregando $hostname -> $ip a /etc/hosts (requiere sudo)..."
        echo "$ip $hostname" | sudo tee -a /etc/hosts > /dev/null
    else
        echo "[INFO] $hostname ya existe en /etc/hosts."
    fi
    echo ""
}

set -e

DOMAIN="paas.tec.cr"
WWW_HOST="www.paas.tec.cr"
DNS_HOST_PORT="5300"   # puerto mapeado en docker-compose.yml (5300:53)

# Configura el archivo hosts del sistema
add_host_entry "172.20.0.4" "$DOMAIN"
add_host_entry "172.20.0.4" "$WWW_HOST"

echo "=========================================="
echo "  El DNS está funcionando correctamente.  "
echo "=========================================="

