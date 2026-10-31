#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v dart >/dev/null 2>&1; then
  echo 'Dart não encontrado no PATH. Use o terminal em que flutter e dart funcionam.'
  exit 1
fi
if ! command -v zenity >/dev/null 2>&1 || ! command -v notify-send >/dev/null 2>&1; then
  echo 'Dependências: sudo apt install zenity libnotify-bin libcanberra-gtk3-module'
  exit 1
fi

flutter pub get
mkdir -p build/motor
# Construir executable da mesma arquitetura deste Linux.
dart compile exe bin/motor_alarmes.dart -o build/motor/motor_alarmes

mapfile -d '' BANCOS < <(find "$HOME/.local/share" -type f -name cronograma_remedios.db -print0 2>/dev/null)
if [ "${#BANCOS[@]}" -ne 1 ]; then
  echo "Foram encontrados ${#BANCOS[@]} bancos."
  echo 'Edite a variável CAMINHO_BANCO e execute este script novamente.'
  exit 1
fi
BANCO="${BANCOS[0]}"
BINARIO="$(pwd)/build/motor/motor_alarmes"
UNIDADE="$HOME/.config/systemd/user/cronograma-motor.service"
mkdir -p "$(dirname "$UNIDADE")"
# A configuração do systemd aceita paths com espaços entre aspas.
cat > "$UNIDADE" <<SERVICE
[Unit]
Description=Motor de alarmes dos medicamentos

[Service]
Type=simple
ExecStart="$BINARIO" --banco "$BANCO"
Restart=on-failure
RestartSec=15s
LogLevelMax=err
StandardOutput=null
StandardError=journal
Nice=10

[Install]
WantedBy=default.target
SERVICE

# Evita alarmes duplicados do serviço Python antigo.
systemctl --user disable --now cronograma-remedios.timer 2>/dev/null || true
systemctl --user stop cronograma-remedios.service 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable --now cronograma-motor.service
systemctl --user status cronograma-motor.service --no-pager
