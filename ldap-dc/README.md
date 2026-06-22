# Linux Domain Controller con LDAP sincronizado con Active Directory

Laboratorio 100% local (sin IP pública ni dominio DNS real) para la
asignación: un servidor Linux que actúa como **controlador de dominio**,
expone su propio **LDAP**, y se mantiene **sincronizado con Active
Directory**.

## Decisiones de diseño

No se dispone de un Windows Server / Active Directory real ni de
infraestructura pública, así que se optó por lo siguiente:

- **Docker + Samba 4 AD DC.** Samba, en modo "Active Directory Domain
  Controller", es protocolo-compatible con Microsoft AD: implementa
  LDAP, Kerberos, DNS integrado y el protocolo de replicación nativo
  de AD (DRS). Es la única forma de tener un controlador de dominio en
  Linux que realmente "sincroniza con AD", no solo una copia paralela.
- **Dos contenedores:**
  - `dc1` → simula el rol de "Active Directory" central. Aprovisiona
    un dominio nuevo: `LAB.LOCAL` (NetBIOS `LAB`).
  - `dc2` → es el **entregable**: el "Linux Domain Controller". Se une
    al dominio como **controlador de dominio adicional**, replicando
    automáticamente usuarios, grupos, contraseñas y políticas vía DRS,
    y sirviendo su propio LDAP (puertos 389/636) sobre esos mismos
    datos.

> Si en algún momento cuentas con un Windows Server con AD real (por
> ejemplo en otra parte de tu entorno académico), no necesitas `dc1`:
> simplemente cambia `PRIMARY_DC_IP` y `DOMAIN_REALM` en el servicio
> `dc2` de `docker-compose.yml` para que apunten a ese AD real. El
> comando `samba-tool domain join` es exactamente el mismo.

## Estructura del proyecto

```
linux-dc-lab/
├── docker-compose.yml      # Orquesta dc1 (AD) y dc2 (Linux DC)
├── common/
│   ├── Dockerfile          # Imagen base con Samba AD DC, usada por ambos
│   └── entrypoint.sh       # Decide si aprovisiona (dc1) o se une (dc2)
└── README.md
```

## Requisitos

- Docker Engine + plugin `docker compose`
- Modo `privileged` habilitado (Samba AD DC necesita varias
  capacidades del kernel para gestionar ACLs y el entorno Kerberos)
- ~2 GB de RAM libres

## Despliegue

```bash
cd linux-dc-lab
docker compose up -d --build
```

Seguir los logs hasta ver `Iniciando el servicio Samba` en ambos:

```bash
docker compose logs -f dc1
docker compose logs -f dc2
```

El primer arranque de `dc2` tarda más porque espera a que `dc1` esté
disponible y luego ejecuta el join (replicación inicial completa del
dominio: esquema, usuarios, GPOs, SysVol, etc.).

## Verificar que dc2 es un controlador de dominio funcional

```bash
docker exec -it dc2 samba-tool domain level show
docker exec -it dc2 samba-tool drs showrepl
```

`drs showrepl` debe mostrar a `dc1` como socio de replicación entrante
y saliente.

## Probar la sincronización (lo importante para la entrega)

1. **Crear un usuario en el "Active Directory" (dc1):**

   ```bash
   docker exec -it dc1 samba-tool user create jdoe 'Passw0rd123!' \
       --given-name=John --surname=Doe
   ```

2. **Forzar la replicación inmediata hacia el Linux DC** (por defecto
   Samba replica solo cada pocos minutos; para la demo la forzamos):

   ```bash
   docker exec -it dc2 samba-tool drs replicate dc2 dc1 DC=lab,DC=local --sync-forced
   ```

   > El tercer argumento es el *naming context*, y debe ir en formato
   > DN (`DC=lab,DC=local`), **no** como nombre DNS (`lab.local`).
   > Usar `lab.local` directamente produce el error
   > `WERR_DS_DRA_BAD_NC` porque Samba no lo reconoce como un NC válido.

3. **Confirmar que el usuario ya existe en el LDAP propio de dc2:**

   ```bash
   docker exec -it dc2 samba-tool user list | grep -i jdoe
   ```

   Para consultar vía LDAP directamente, **Samba (igual que un AD real)
   rechaza el "simple bind" en texto plano** si el canal no está
   cifrado o firmado — verás el error
   `Strong(er) authentication required / Transport encryption required`
   si lo intentas con `-x` sobre `ldap://` sin más. Hay dos formas
   correctas de consultar:

   **a) Bind Kerberos (GSSAPI) — la forma nativa de AD.** Requiere un
   ticket válido (`kinit administrator@LAB.LOCAL` primero):

   ```bash
   docker exec -it dc2 kinit administrator@LAB.LOCAL
   docker exec -it dc2 ldapsearch -Y GSSAPI -H ldap://localhost \
       -b "dc=lab,dc=local" "(sAMAccountName=jdoe)"
   ```

   **b) Simple bind sobre LDAPS** (más simple para pruebas rápidas;
   se ignora la validación del certificado autofirmado de Samba):

   ```bash
   docker exec -it dc2 bash -c \
       "LDAPTLS_REQCERT=never ldapsearch -x -H ldaps://localhost \
       -D 'administrator@lab.local' -w 'Passw0rd123!' \
       -b 'dc=lab,dc=local' '(sAMAccountName=jdoe)'"
   ```

4. **Probar el camino inverso** (crear en dc2, verificar en dc1) para
   confirmar que la sincronización es bidireccional, como corresponde
   a una replicación multi-maestro de AD:

   ```bash
   docker exec -it dc2 samba-tool user create asmith 'Passw0rd123!'
   docker exec -it dc1 samba-tool drs replicate dc1 dc2 DC=lab,DC=local --sync-forced
   docker exec -it dc1 samba-tool user list | grep -i asmith
   ```

## Consultar el LDAP desde el host (fuera de los contenedores)

Los puertos LDAP/LDAPS están mapeados al host:

| Servidor | LDAP (host) | LDAPS (host) |
|----------|-------------|---------------|
| dc1 (AD) | `localhost:1389` | `localhost:1636` |
| dc2 (Linux DC) | `localhost:2389` | `localhost:2636` |

```bash
LDAPTLS_REQCERT=never ldapsearch -x -H ldaps://localhost:2636 \
    -D "administrator@lab.local" -w 'Passw0rd123!' \
    -b "dc=lab,dc=local" "(objectClass=user)"
```

> Igual que en el paso anterior, el simple bind solo funciona sobre
> un canal cifrado (LDAPS, puerto 636/2636), nunca en texto plano.

También puedes usar un cliente gráfico como **Apache Directory Studio**
o **JXplorer** contra `localhost:2389` con esas mismas credenciales.

## Autenticación Kerberos de prueba

```bash
docker exec -it dc2 kinit administrator@LAB.LOCAL
docker exec -it dc2 klist
```

## Notas y limitaciones del entorno académico

- Dominio ficticio `LAB.LOCAL`, sin necesidad de DNS público ni IP
  pública: todo vive en una red interna de Docker (`172.28.0.0/24`).
- Contraseña de ejemplo `Passw0rd123!`; cámbiala con la variable de
  entorno `ADMIN_PASSWORD` en `docker-compose.yml` antes de desplegar.
- `privileged: true` simplifica el laboratorio. En un entorno
  productivo se debería limitar a capacidades puntuales (`SYS_ADMIN`,
  `NET_ADMIN`, `DAC_READ_SEARCH`).
- Los datos de Samba (`/var/lib/samba`) y la configuración
  (`/etc/samba`) están en volúmenes Docker, por lo que sobreviven a
  reinicios de los contenedores (`docker compose restart`), pero no a
  un `docker compose down -v`.

## Limpieza completa

```bash
docker compose down -v
```

Esto elimina los contenedores y los volúmenes (vuelve a un estado
limpio para re-provisionar desde cero).