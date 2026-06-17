FROM debian:bookworm-slim

# isc-dhcp-server: implementación de DHCPD pedida en el enunciado
# iproute2 / tcpdump: utilidades para depurar/demostrar el protocolo
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        isc-dhcp-server \
        iproute2 \
        tcpdump && \
    rm -rf /var/lib/apt/lists/*

COPY dhcpd.conf /etc/dhcp/dhcpd.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 67/udp

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
