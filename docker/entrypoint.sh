#!/bin/sh

set -eu

WORK_DIR="${WORK_DIR:-/opt/mendyfi}"
KEY_FILE="${KEY_FILE:-${WORK_DIR}/key.pem}"
CERT_FILE="${CERT_FILE:-${WORK_DIR}/cert.pem}"
CERT_DAYS="${CERT_DAYS:-365}"
FORCE_REGENERATE_CERT="${FORCE_REGENERATE_CERT:-false}"

mkdir -p "${WORK_DIR}"

collect_server_ips() {
  ips=""

  public_ip=""
  if [ -n "${PUBLIC_IP:-}" ]; then
    public_ip="${PUBLIC_IP}"
  else
    public_ip="$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  fi

  if [ -n "${public_ip}" ]; then
    ips="${public_ip}"
  fi

  lan_ips="$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || true)"

  for ip_addr in ${lan_ips}; do
    [ -z "${ip_addr}" ] && continue
    case " ${ips} " in
      *" ${ip_addr} "*) ;;
      *)
        if [ -z "${ips}" ]; then
          ips="${ip_addr}"
        else
          ips="${ips} ${ip_addr}"
        fi
        ;;
    esac
  done

  echo "${ips}"
}

generate_certificate() {
  ips="$(collect_server_ips)"

  if [ -z "${ips}" ]; then
    echo "[WARN] No public/LAN IP detected. Skipping certificate generation."
    return 0
  fi

  cn_ip="${ips%% *}"
  san_entries=""
  for ip_addr in ${ips}; do
    if [ -z "${san_entries}" ]; then
      san_entries="IP:${ip_addr}"
    else
      san_entries="${san_entries},IP:${ip_addr}"
    fi
  done

  cert_conf="$(mktemp)"
  cat > "${cert_conf}" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = dn

[dn]
CN = ${cn_ip}

[v3_req]
subjectAltName = ${san_entries}
EOF

  openssl req -x509 -newkey rsa:2048 \
    -keyout "${KEY_FILE}" \
    -out "${CERT_FILE}" \
    -days "${CERT_DAYS}" \
    -nodes \
    -subj "/CN=${cn_ip}" \
    -extensions v3_req \
    -config "${cert_conf}" >/dev/null 2>&1

  chmod 600 "${KEY_FILE}"
  chmod 644 "${CERT_FILE}"
  rm -f "${cert_conf}"

  echo "[INFO] TLS certificate generated"
  echo "[INFO]  - key : ${KEY_FILE}"
  echo "[INFO]  - cert: ${CERT_FILE}"
  echo "[INFO]  - SAN : ${ips}"
}

if [ "${FORCE_REGENERATE_CERT}" = "true" ] || [ ! -s "${KEY_FILE}" ] || [ ! -s "${CERT_FILE}" ]; then
  generate_certificate
else
  echo "[INFO] Existing certificate found, skipping generation."
fi

cd "${WORK_DIR}"
exec /usr/local/bin/mendyfi