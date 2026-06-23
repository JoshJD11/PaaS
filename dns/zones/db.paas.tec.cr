$TTL 604800
@   IN  SOA ns1.paas.tec.cr. admin.paas.tec.cr. (
            2026061301  ; Serial
            604800      ; Refresh
            86400       ; Retry
            2419200     ; Expire
            604800 )    ; Negative TTL

; Servidores de nombre
@       IN  NS      ns1.paas.tec.cr.

; Registros A — IPs de la red bridge de Docker (172.20.0.x)
ns1     IN  A       172.20.0.2
www     IN  A       172.20.0.4
db      IN  A       172.20.0.3

; CNAME para acceder al sitio por el dominio raíz
@       IN  A       172.20.0.4
