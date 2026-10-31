
#!/usr/bin/env bash
set -euo pipefail

PROJETO="$HOME/desenvolvimento/cronograma_remedios"
SERVICOS="$HOME/.config/systemd/user"

mkdir -p "$SERVICOS"

cat > "$SERVICOS/cronograma-remedios.service" <<EOF
[Unit]
Description=Verificador de alarmes dos medicamentos

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 "$PROJETO/scripts/alarme_linux.py"
EOF

cat > "$SERVICOS/cronograma-remedios.timer" <<'EOF'
[Unit]
Description=Verificar os medicamentos a cada minuto

[Timer]
OnCalendar=*-*-* *:*:00
AccuracySec=1s
Persistent=false
Unit=cronograma-remedios.service

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload

systemctl --user enable --now cronograma-remedios.timer

echo ""
echo "Serviço de alarmes instalado."
echo "Situação atual:"
systemctl --user list-timers cronograma-remedios.timer
EOF
