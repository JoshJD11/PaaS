#!/bin/bash

if [ -z "$1" ]; then
  echo "Uso:"
  echo "  $0 --pull    Importa BBB-Docker con sus submodulos"
  echo "  $0 --build   Construye y ejecuta el entorno"
  echo "  $0 --up      Levanta los servicios (en modo detach)"
  echo "  $0 --down    Detiene los servicios"
  echo ""
  exit 1
fi

cd ../

case "$1" in
  --pull)
    git clone --recurse-submodules https://github.com/Sebco27/bbb-docker.git bbb-docker
    ;;
esac

cd bbb-docker || exit 1

case "$1" in
  --build)
    sudo ./scripts/build.sh
    ;;
  --up)
    sudo docker compose up -d
    EXTERNAL_IPv4=$(ip route get 8.8.8.8 | head -1 | awk '{ print $7 }')
    echo "============================================"
    echo "BBB Development Server"
    echo ""
    echo "API: https://mconf.github.io/api-mate/#server=https://${EXTERNAL_IPv4}/bigbluebutton/api&sharedSecret=SuperSecret"
    echo "============================================"
    ;;
  --down)
    sudo docker compose down
    ;;
esac

