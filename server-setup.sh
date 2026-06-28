#!/usr/bin/env bash
#
# ─────────────────────────────────────────────────────────────────────────────
#  SLV Auto Consultant — ONE-TIME server bootstrap (run ONCE on the VPS)
# ─────────────────────────────────────────────────────────────────────────────
#
#  Builds BOTH stacks on your Hostinger VPS so GitHub Actions can take over:
#
#    PROD → /opt/slv      branch main  db slv_auto_prod  service slv-api      :8000 → nginx :80
#    DEV  → /opt/slv-dev  branch dev   db slv_auto_dev   service slv-api-dev  :8001 → nginx :8080
#
#  HOW TO RUN (on the VPS, as root):
#     git clone -b main https://<TOKEN>@github.com/jpcryptowallet07-sys/slvautmobiles.git ~/slv-bootstrap
#     cd ~/slv-bootstrap
#     sudo GITHUB_TOKEN=<TOKEN> bash server-setup.sh
#
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Matches what you already created on the VPS ──────────────────────────────
REPO="github.com/jpcryptowallet07-sys/slvautmobiles.git"
DB_USER="slvuser"
DB_PASS_RAW="Jai@@0307"        # the real DB password
DB_PASS_URL="Jai%40%400307"    # same password, @ -> %40 for the SQLAlchemy URL
PROD_DB="slv_auto_prod"
DEV_DB="slv_auto_dev"

# GitHub token must be provided (private repo). Pass it on the command line:
#   sudo GITHUB_TOKEN=ghp_xxx bash server-setup.sh
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN env var (your GitHub PAT) before running}"
REPO_URL="https://${GITHUB_TOKEN}@${REPO}"
# ─────────────────────────────────────────────────────────────────────────────

echo "==> 1/7  Installing system packages (python, postgres, nginx, git)…"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3-venv python3-pip postgresql nginx git
systemctl enable --now postgresql

echo "==> 2/7  Ensuring DB user + BOTH databases + privileges…"
sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='${DB_USER}') THEN
    CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS_RAW}';
  END IF;
END \$\$;
ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASS_RAW}';
SELECT 'CREATE DATABASE ${PROD_DB} OWNER ${DB_USER}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname='${PROD_DB}')\gexec
SELECT 'CREATE DATABASE ${DEV_DB}  OWNER ${DB_USER}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname='${DEV_DB}')\gexec
ALTER DATABASE ${PROD_DB} OWNER TO ${DB_USER};
ALTER DATABASE ${DEV_DB}  OWNER TO ${DB_USER};
SQL
# slvuser must be able to create tables in the public schema (Postgres 15+ locks it down)
sudo -u postgres psql -d "${PROD_DB}" -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"
sudo -u postgres psql -d "${DEV_DB}"  -c "GRANT ALL ON SCHEMA public TO ${DB_USER};"
echo "    databases ready: ${PROD_DB} (prod) + ${DEV_DB} (dev)"

# Helper: set up one stack. args: <dir> <branch> <dbname> <app_env>
setup_stack () {
  local DIR="$1" BRANCH="$2" DB="$3" APP_ENV="$4"
  echo "==> Setting up stack: $DIR  (branch=$BRANCH, db=$DB)"

  if [ -d "$DIR/.git" ]; then
    git -C "$DIR" remote set-url origin "$REPO_URL"
    git -C "$DIR" fetch origin
    git -C "$DIR" checkout "$BRANCH"
    git -C "$DIR" pull origin "$BRANCH"
  else
    git clone -b "$BRANCH" "$REPO_URL" "$DIR"
  fi

  python3 -m venv "$DIR/venv"
  "$DIR/venv/bin/pip" install --upgrade pip
  "$DIR/venv/bin/pip" install -r "$DIR/backend/requirements.txt"

  # per-environment .env (its OWN database — dev never touches prod data)
  cat > "$DIR/backend/.env" <<ENV
DATABASE_URL=postgresql+psycopg2://${DB_USER}:${DB_PASS_URL}@localhost:5432/${DB}
APP_ENV=${APP_ENV}
ENV
  chmod 600 "$DIR/backend/.env"

  # create tables + seed super-admin (Alembic does this — never create tables by hand)
  ( cd "$DIR/backend" && "$DIR/venv/bin/alembic" upgrade head )
}

echo "==> 3/7  PROD stack…"
setup_stack /opt/slv      main "$PROD_DB" production

echo "==> 4/7  DEV stack…"
setup_stack /opt/slv-dev  dev  "$DEV_DB"  development

echo "==> 5/7  Log directories for gunicorn…"
mkdir -p /var/log/slv-api /var/log/slv-api-dev

echo "==> 6/7  Installing systemd services (prod + dev)…"
cp /opt/slv/slv-api.service          /etc/systemd/system/slv-api.service
cp /opt/slv/slv-api-dev.service      /etc/systemd/system/slv-api-dev.service
systemctl daemon-reload
systemctl enable --now slv-api
systemctl enable --now slv-api-dev

echo "==> 7/7  Installing nginx reverse proxy (:80 → prod, :8080 → dev)…"
cp /opt/slv/nginx.conf /etc/nginx/sites-available/slv.conf
ln -sf /etc/nginx/sites-available/slv.conf /etc/nginx/sites-enabled/slv.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

# open the firewall if ufw is active
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow 22 ; ufw allow 80 ; ufw allow 8080
fi

echo ""
echo "─────────────────────────────────────────────────────────────────────"
echo " DONE. Verify:"
echo "   PROD : curl http://127.0.0.1:8000/health   (public: http://187.127.186.206/health)"
echo "   DEV  : curl http://127.0.0.1:8001/health   (public: http://187.127.186.206:8080/health)"
echo ""
echo " Seeded login (BOTH envs):  owner@slvauto.in / Admin@123"
echo " >> Change the PROD password after first login."
echo "─────────────────────────────────────────────────────────────────────"
