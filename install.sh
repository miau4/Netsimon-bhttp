#!/usr/bin/env bash
set -e

echo "=== Instalador Netsimon-BHTTP ==="

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/netsimon-bhttp"
BIN_NAME="netsimon-bhttp"
RELEASE_URL="https://github.com/miau4/Netsimon-bhttp/releases/download/v1.0/netsimon-bhttp-linux-amd64.tar.gz"
EXPECTED_SHA256="53909243141d6ad91820704ad2c3b71a332e425195311a734b2a0ef48c8d7d2a"

if [ "$EUID" -ne 0 ]; then
  echo "Execute como root (sudo)."
  exit 1
fi

echo "[1/6] Baixando binário..."
TMP_DIR=$(mktemp -d)
curl -fsSL "$RELEASE_URL" -o "$TMP_DIR/pkg.tar.gz"

echo "[2/6] Verificando integridade..."
ACTUAL_SHA256=$(sha256sum "$TMP_DIR/pkg.tar.gz" | awk '{print $1}')
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "ERRO: checksum não confere!"
  echo "Esperado: $EXPECTED_SHA256"
  echo "Obtido:   $ACTUAL_SHA256"
  exit 1
fi
echo "Checksum OK."

echo "[3/6] Extraindo e instalando binário..."
tar -xzf "$TMP_DIR/pkg.tar.gz" -C "$TMP_DIR"
mv "$TMP_DIR/$BIN_NAME" "$INSTALL_DIR/$BIN_NAME"
chmod +x "$INSTALL_DIR/$BIN_NAME"

echo "[4/6] Criando configuração..."
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.json" ]; then
cat > "$CONFIG_DIR/config.json" << 'EOF'
{
  "server": {
    "virtual_subnet_cidr": "10.10.0.0/16",
    "stats_file": "/etc/netsimon-bhttp/stats.json",
    "auth": {
      "system": true
    },
    "tun": {
      "name": "tun0",
      "buffer_size": 65536
    }
  },
  "proxy": {
    "enabled": true,
    "listen": [
      {
        "host": "0.0.0.0",
        "port": 443,
        "ssl": true
      },
      {
        "host": "0.0.0.0",
        "port": 80,
        "ssl": false
      }
    ]
  }
}
EOF
else
  echo "Config já existe, mantendo."
fi

echo "[5/6] Criando serviço systemd..."
cat > /etc/systemd/system/netsimon-bhttp.service << EOF
[Unit]
Description=Netsimon BHTTP Server
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/$BIN_NAME --config $CONFIG_DIR/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

echo "[6/6] Ativando serviço..."
systemctl daemon-reload
systemctl enable netsimon-bhttp.service
systemctl restart netsimon-bhttp.service

rm -rf "$TMP_DIR"

echo ""
echo "=== Instalação concluída ==="
systemctl status netsimon-bhttp.service --no-pager
