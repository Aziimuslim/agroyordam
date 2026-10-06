#!/usr/bin/env bash
# Avtomatik deploy'ni yoqish — serverda BIR MARTA ishga tushiriladi:
#   cd /opt/agroyordam && sudo git pull && sudo bash deploy/enable-autodeploy.sh
#
# Faqat deploy uchun alohida SSH kalit yaratadi va uni cheklaydi: bu kalit bilan
# faqat deploy/deploy.sh ishga tushadi (shell ochib bo'lmaydi). Oxirida GitHub'ga
# qo'yiladigan 3 ta secret chiqariladi.
set -euo pipefail

DIR=/opt/agroyordam
USER_NAME="${SUDO_USER:-ubuntu}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
KEY="$HOME_DIR/.ssh/agroyordam_deploy"
AUTH="$HOME_DIR/.ssh/authorized_keys"

[ "$(id -u)" -eq 0 ] || { echo "sudo bilan ishga tushiring: sudo bash deploy/enable-autodeploy.sh"; exit 1; }
chmod +x "$DIR/deploy/deploy.sh"
# deploy.sh `sudo` bilan parolsiz chaqiriladi (Oracle/Ubuntu'da ubuntu foydalanuvchisi uchun odatda shunday)
sudo -u "$USER_NAME" sudo -n true 2>/dev/null || {
  echo "$USER_NAME ALL=(root) NOPASSWD: $DIR/deploy/deploy.sh" > /etc/sudoers.d/agroyordam-deploy
  chmod 440 /etc/sudoers.d/agroyordam-deploy
}

mkdir -p "$HOME_DIR/.ssh"
if [ ! -f "$KEY" ]; then
  ssh-keygen -q -t ed25519 -N "" -C "agroyordam-github-deploy" -f "$KEY"
fi
PUB="$(cat "$KEY.pub")"
LINE="command=\"sudo $DIR/deploy/deploy.sh\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty $PUB"
touch "$AUTH"
grep -qF "$PUB" "$AUTH" || echo "$LINE" >> "$AUTH"
chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR/.ssh"
chmod 700 "$HOME_DIR/.ssh"; chmod 600 "$AUTH" "$KEY"

IP="$(curl -s --max-time 5 https://api.ipify.org || hostname -I | awk '{print $1}')"
cat <<EOF

✅ Deploy kaliti tayyor. Endi GitHub'da 3 ta secret qo'shing:
   https://github.com/Aziimuslim/agroyordam/settings/secrets/actions  →  "New repository secret"

   1) Name: SERVER_HOST      Value: $IP
   2) Name: SERVER_USER      Value: $USER_NAME
   3) Name: SERVER_SSH_KEY   Value: pastdagi butun matn (-----BEGIN dan -----END gacha, ikkalasi ham kiradi)

$(cat "$KEY")

⚠️  Bu maxfiy kalitni faqat GitHub secret'iga qo'ying, boshqa hech kimga bermang.
    U faqat deploy skriptini ishga tushira oladi, lekin baribir maxfiy saqlang.
EOF
