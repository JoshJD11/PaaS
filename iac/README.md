# VPN con IaC — OpenVPN sobre AWS (Terraform + Ansible)

Este componente cumple el rubro **"VPN con IaC: 20%"**. A diferencia de los
demás servicios (que viven en `docker-compose.yml`), este NO corre en un
contenedor: el enunciado pide explícitamente un servidor "previamente
instalado en Amazon Web Services", así que la VPN se monta en una instancia
EC2 real, aprovisionada con **Terraform** y configurada con **Ansible**.

## Por qué esta arquitectura

El enunciado pide protocolo **TCP** e interfaz **TAP** (no TUN). TAP implica
operar en modo *bridging* (capa 2), pero **AWS VPC no permite bridging real**
contra la interfaz física de la instancia (el fabric de red de AWS descarta
tramas cuyo MAC/IP no coincide con el de la ENI asignada). La solución
estándar de la comunidad de OpenVPN para este caso es el **"private bridge"**:
un bridge (`br0`) que vive aislado, sin tocar `eth0`, donde solo se conectan
las interfaces `tap` de los clientes VPN. OpenVPN actúa como switch L2 entre
los dispositivos conectados (laptop y teléfono) y como DHCP de esa mini-LAN
virtual (directiva `server-bridge`). Para la salida a Internet se agrega una
regla NAT (MASQUERADE) hacia `eth0`, así los paquetes sí se rutean a través
del servidor, como pide el enunciado.

```
                 AWS EC2 (Terraform)
        ┌─────────────────────────────────┐
        │   eth0 (IP elástica pública)     │── Internet (vía MASQUERADE)
        │                                  │
        │   br0 (10.8.0.1/24) ── tap0      │
        │        │                         │
        │   OpenVPN server (TCP/1194)      │
        └─────────────────────────────────┘
              │  TCP 1194              │  TCP 1194
        ┌─────┴─────┐            ┌─────┴─────┐
        │  Laptop    │            │  Teléfono  │
        │ 10.8.0.5x  │            │ 10.8.0.5x  │
        └────────────┘            └────────────┘
```

## ⚠️ Importante: compatibilidad de clientes con TAP

Los clientes basados en **OpenVPN3** (la app moderna "OpenVPN Connect" para
Windows/macOS/Android/iOS) **no soportan TAP** y rechazan el perfil con el
error `TAP mode is not supported`. Hay que usar un cliente **OpenVPN2**:

| Dispositivo | Cliente recomendado |
|---|---|
| Windows | "OpenVPN GUI" (instalador clásico desde openvpn.net/community-downloads, **no** "OpenVPN Connect") |
| macOS | Tunnelblick |
| Linux | paquete `openvpn` (línea de comandos: `sudo openvpn --config desktop.ovpn`) |
| Android | OpenVPN Connect **no sirve**. Alternativa verificada: app de pago "VPN Client Pro" (colucci-web.it), emula TAP sin root |
| iOS | No se conoce un cliente actual que soporte TAP. Documentar como limitación si es tu caso, o usar Android/laptop para la demo del "teléfono" |

Esto es una limitación real del protocolo/plataforma, no un error de
configuración — vale la pena explicarlo así en la sección de Autoevaluación
de tu documentación si tu defensa usa un Android con VPN Client Pro o si
decidís documentar la limitación de iOS en vez de resolverla.

## Paso 1 — Prerrequisitos en AWS

1. Crear (o reusar) un **Key Pair** en la consola EC2 (Network & Security →
   Key Pairs) y descargar el `.pem`.
2. Tener credenciales de AWS configuradas en tu máquina:
   `aws configure` (Access Key, Secret Key, región).
3. Averiguar tu IP pública actual (para `admin_cidr`): `curl ifconfig.me`.

## Paso 2 — Terraform: aprovisionar el servidor

```bash
cd iac/terraform
cp terraform.tfvars.example terraform.tfvars
# editar terraform.tfvars con tu ami_id, key_pair_name y admin_cidr

terraform init
terraform plan
terraform apply
```

Al terminar, anotar la IP pública:
```bash
terraform output openvpn_public_ip
```

## Paso 3 — Ansible: configurar OpenVPN

```bash
cd ../ansible
ansible-galaxy collection install -r requirements.yml   # una sola vez

cp inventory.ini.example inventory.ini
# reemplazar la IP por la que dio "terraform output", y la ruta a tu .pem

ansible-playbook playbook.yml
```

El playbook hace, en orden: instala `openvpn` + `easy-rsa`, habilita IP
forwarding, construye la PKI completa (CA, certificado de servidor, DH,
llave `tls-crypt`), crea el bridge privado `br0`/`tap0` vía un servicio
systemd propio (`openvpn-bridge.service`), despliega `server.conf` (TCP +
`dev tap0` + `server-bridge`), agrega la regla NAT, y por último genera y
descarga automáticamente los perfiles `.ovpn` de **dos clientes**
(`desktop` y `phone`) a la carpeta `iac/ansible/clients/`.

## Paso 4 — Probar la conexión

**Desde Linux/laptop** (cliente OpenVPN2, viene en el paquete `openvpn`):
```bash
sudo openvpn --config clients/desktop.ovpn
```
Deberías obtener una IP en el rango `10.8.0.50-100` (`ip addr show tap0`).

**Desde el teléfono**: importar `clients/phone.ovpn` en VPN Client Pro
(Android) y conectar.

**Verificar que los paquetes se rutean a través del servidor**: con ambos
clientes conectados, hacer ping entre ellos usando sus IPs `10.8.0.x`
(prueba la parte de "bridging"/LAN virtual) y, por separado, verificar
salida a Internet desde un cliente conectado (prueba la parte de NAT).

```bash
# en el servidor, para ver las sesiones activas:
ssh -i tu-llave.pem ubuntu@<ip-publica> 'sudo cat /var/log/openvpn/openvpn-status.log'
```

## Re-ejecutar / agregar más clientes

El playbook es idempotente: volver a correr `ansible-playbook playbook.yml`
no rompe nada (los pasos de generación de PKI usan `creates:` para no
repetirse). Para agregar un tercer dispositivo, basta con sumarlo a la
lista `vpn_clients` en `playbook.yml` y volver a correr el playbook — solo
se generará el certificado y el `.ovpn` del cliente nuevo.

## Destruir la infraestructura (para no dejar la instancia encendida)

```bash
cd iac/terraform
terraform destroy
```
