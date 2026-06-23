#!/usr/bin/env python3
# Cliente TFTP mínimo (RFC 1350, modo "octet") usado solo para el
# smoke test del ltsp_server. Se hizo a mano porque los clientes
# tftp de los paquetes de Alpine (tftp-hpa, busybox-extras, curl)
# dieron tres bugs distintos en la VM de prueba.
import socket
import sys

HOST = "172.30.0.11"
PORT = 69
REMOTE_FILE = "pxelinux.0"
LOCAL_FILE = "/tmp/pxelinux.0"

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(5)

# RRQ (opcode 1): pedir el archivo en modo "octet" (binario)
req = b"\x00\x01" + REMOTE_FILE.encode() + b"\x00octet\x00"
s.sendto(req, (HOST, PORT))

data = b""
expected_block = 1

while True:
    try:
        pkt, addr = s.recvfrom(516)
    except socket.timeout:
        print("ERROR: timeout esperando datos del servidor TFTP")
        sys.exit(1)

    opcode = int.from_bytes(pkt[0:2], "big")

    if opcode == 5:  # ERROR
        print("ERROR TFTP del servidor:", pkt[4:-1].decode(errors="replace"))
        sys.exit(1)

    if opcode != 3:  # esperamos DATA
        print(f"ERROR: opcode inesperado {opcode}")
        sys.exit(1)

    block = int.from_bytes(pkt[2:4], "big")
    payload = pkt[4:]

    if block == expected_block:
        data += payload
        ack = b"\x00\x04" + pkt[2:4]
        s.sendto(ack, addr)
        expected_block += 1
    else:
        # bloque repetido/duplicado: re-confirmamos el último válido
        ack = b"\x00\x04" + (block).to_bytes(2, "big")
        s.sendto(ack, addr)

    if len(payload) < 512:
        break

with open(LOCAL_FILE, "wb") as f:
    f.write(data)

print(f"--- Descarga TFTP OK: {len(data)} bytes en {LOCAL_FILE} ---")