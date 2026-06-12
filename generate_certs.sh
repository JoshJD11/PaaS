#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Genera una Entidad Certificadora (CA) propia y un certificado
# autofirmado para el servidor HTTPS.
# Requerimiento del proyecto: OpenSSL, documentar todo el proceso.
# ─────────────────────────────────────────────────────────────

CERTS_DIR="./nginx/certs"
mkdir -p "$CERTS_DIR"

echo "==> 1. Generando clave privada de la CA..."
openssl genrsa -out "$CERTS_DIR/ca.key" 4096

echo "==> 2. Generando certificado raíz de la CA (válido 10 años)..."
openssl req -x509 -new -nodes \
    -key "$CERTS_DIR/ca.key" \
    -sha256 -days 3650 \
    -out "$CERTS_DIR/ca.crt" \
    -subj "/C=CR/ST=SanJose/O=TEC-Redes/CN=MiCA"

echo "==> 3. Generando clave privada del servidor..."
openssl genrsa -out "$CERTS_DIR/server.key" 2048

echo "==> 4. Generando solicitud de firma (CSR) del servidor..."
openssl req -new \
    -key "$CERTS_DIR/server.key" \
    -out "$CERTS_DIR/server.csr" \
    -subj "/C=CR/ST=SanJose/O=TEC-Redes/CN=localhost"

echo "==> 5. Firmando el certificado del servidor con nuestra CA..."
openssl x509 -req \
    -in "$CERTS_DIR/server.csr" \
    -CA "$CERTS_DIR/ca.crt" \
    -CAkey "$CERTS_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERTS_DIR/server.crt" \
    -days 365 \
    -sha256

echo ""
echo "✅ Certificados generados en $CERTS_DIR:"
ls -lh "$CERTS_DIR"
echo ""
echo "Archivos usados por Nginx:"
echo "  - server.crt (certificado del servidor)"
echo "  - server.key (clave privada del servidor)"
