# ─────────────────────────────────────────────────────────
# start-dns-stack.ps1
# Configura el Port Forwarding de VirtualBox, abre el puerto
# en el Firewall de Windows, y valida que el DNS (BIND9 dentro
# de la VM) responda correctamente desde el host Windows.
#
# IMPORTANTE: este script es para el caso especial donde Docker
# corre dentro de una VM de VirtualBox (no Linux nativo).
# Debe ejecutarse como Administrador.
#
# Uso:
#   Click derecho -> "Ejecutar con PowerShell" (como Administrador)
#   o desde una consola de PowerShell con permisos elevados:
#   .\start-dns-stack.ps1
# ─────────────────────────────────────────────────────────

# Ajusta estos valores según tu entorno
$VMName        = "NOMBRE_DE_TU_VM"      # Nombre exacto en VirtualBox
$VMInternalIP  = "10.0.2.15"            # IP de la VM dentro de la red NAT de VirtualBox
$VMInternalPort = 5300                  # Puerto donde escucha el contenedor dns (host de la VM)
$HostExternalPort = 53                  # Puerto que verán otros dispositivos del WiFi
$Domain        = "paas.tec.cr"
$WwwHost       = "www.paas.tec.cr"

$VBoxManagePath = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

Write-Host "=========================================="
Write-Host " PaaS - Configuracion DNS (Windows + VirtualBox)"
Write-Host "=========================================="

# Verifica permisos de administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] Este script debe ejecutarse como Administrador." -ForegroundColor Red
    Write-Host "Cierra esta ventana y vuelve a abrir PowerShell con 'Ejecutar como administrador'."
    exit 1
}

# Verifica que VBoxManage exista
if (-not (Test-Path $VBoxManagePath)) {
    Write-Host "[ERROR] No se encontro VBoxManage.exe en: $VBoxManagePath" -ForegroundColor Red
    Write-Host "Ajusta la variable `$VBoxManagePath en este script con la ruta correcta."
    exit 1
}

# 1. Verifica que la VM exista
Write-Host ""
Write-Host "[1/5] Verificando VMs disponibles..."
$vmList = & $VBoxManagePath list vms
Write-Host $vmList

if ($vmList -notmatch [regex]::Escape($VMName)) {
    Write-Host "[AVISO] No se encontro una VM llamada '$VMName'." -ForegroundColor Yellow
    Write-Host "Edita la variable `$VMName en este script con el nombre exacto (entre comillas) de la lista de arriba."
}

# 2. Configura Port Forwarding en VirtualBox (host 53 -> VM 5300)
Write-Host ""
Write-Host "[2/5] Configurando Port Forwarding en VirtualBox..."
try {
    & $VBoxManagePath controlvm $VMName natpf1 "dns-udp,udp,,$HostExternalPort,,$VMInternalPort" 2>$null
    & $VBoxManagePath controlvm $VMName natpf1 "dns-tcp,tcp,,$HostExternalPort,,$VMInternalPort" 2>$null
    Write-Host "Reglas de Port Forwarding aplicadas (o ya existian)."
} catch {
    Write-Host "[AVISO] La VM debe estar encendida para aplicar reglas en caliente." -ForegroundColor Yellow
    Write-Host "Si fallo, agrega las reglas manualmente desde Configuracion -> Red -> Avanzado -> Reenvio de puertos."
}

# 3. Abre el puerto en el Firewall de Windows
Write-Host ""
Write-Host "[3/5] Configurando reglas de Firewall de Windows..."
$existingRuleUdp = Get-NetFirewallRule -DisplayName "DNS-PaaS-Inbound-UDP" -ErrorAction SilentlyContinue
$existingRuleTcp = Get-NetFirewallRule -DisplayName "DNS-PaaS-Inbound-TCP" -ErrorAction SilentlyContinue

if (-not $existingRuleUdp) {
    New-NetFirewallRule -DisplayName "DNS-PaaS-Inbound-UDP" -Direction Inbound -Protocol UDP -LocalPort $HostExternalPort -Action Allow | Out-Null
    Write-Host "Regla UDP creada."
} else {
    Write-Host "Regla UDP ya existia."
}

if (-not $existingRuleTcp) {
    New-NetFirewallRule -DisplayName "DNS-PaaS-Inbound-TCP" -Direction Inbound -Protocol TCP -LocalPort $HostExternalPort -Action Allow | Out-Null
    Write-Host "Regla TCP creada."
} else {
    Write-Host "Regla TCP ya existia."
}

# 4. Muestra la IP local para compartir con otros dispositivos del WiFi
Write-Host ""
Write-Host "[4/5] IP local de este equipo en la red:"
$localIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback|vEthernet|VirtualBox" }
$localIPs | Select-Object InterfaceAlias, IPAddress | Format-Table -AutoSize

Write-Host "Usa una de estas IPs como servidor DNS en otros dispositivos del WiFi de casa."

# 5. Valida resolucion DNS desde este host
Write-Host ""
Write-Host "[5/5] Validando resolucion DNS..."
Write-Host ""
try {
    $result = Resolve-DnsName -Name $Domain -Server 127.0.0.1 -ErrorAction Stop
    Write-Host "--- Resultado para $Domain ---"
    $result | Format-Table -AutoSize

    $resultWww = Resolve-DnsName -Name $WwwHost -Server 127.0.0.1 -ErrorAction Stop
    Write-Host "--- Resultado para $WwwHost ---"
    $resultWww | Format-Table -AutoSize
} catch {
    Write-Host "[AVISO] No se pudo resolver via Resolve-DnsName. Intentando con nslookup..." -ForegroundColor Yellow
    nslookup $Domain 127.0.0.1
}

Write-Host ""
Write-Host "=========================================="
Write-Host " Listo. Si ves una IP (ej. 172.20.0.4) arriba,"
Write-Host " el DNS esta funcionando correctamente."
Write-Host " Otros dispositivos del WiFi pueden usar la IP"
Write-Host " de este equipo como servidor DNS manual."
Write-Host "=========================================="
