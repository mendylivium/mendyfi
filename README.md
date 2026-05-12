# MendyFi RADIUS

MendyFi RADIUS is a lightweight RADIUS server app that is easier to set up than the original PHP-based version. You run the backend on your own device (Windows or Linux), then manage it using the web frontend.

Frontend URL: http://lite.waspradi.us

## Download

To download the app, go to the repository `binaries` (or Releases binaries) section.

Choose the file that matches your device or OS architecture.

Examples in this project:

- `mendyfi-windows-amd64.exe` for Windows AMD64
- `mendyfi-linux-amd64` for Linux AMD64
- `mendyfi-linux-arm64` for Linux ARM64
- `mendyfi-linux-armv7` for Linux ARMv7
- `mendyfi-openwrt-arm` for OpenWrt ARM
- `mendyfi-openwrt-x86` for OpenWrt x86

# Install App

## For Linux run this line

```
curl -sL https://raw.githubusercontent.com/mendylivium/mendyfi/master/helper_script/linux_installer.sh | sudo bash
```

## For Window

    Download the mendyfi-windows-amd64.exe on binaries folder

## IMPORTANT!

For Linux installer users, TLS certificate files are now generated automatically during install:

- `/opt/mendyfi/key.pem`
- `/opt/mendyfi/cert.pem`

The installer uses your detected public IP and all LAN IP addresses as certificate SAN entries.

If you need to generate it manually, run:

```
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=<server_ip>"
```

Replace `<server_ip>` with your server IP address.

## Docker Usage

Build image:

```bash
cd docker
docker build -t mendyfi:local .
```

Run container:

```bash
docker run -d --name mendyfi \
    -p 3000:3000 \
    -p 1812:1812/udp \
    -p 1813:1813/udp \
    mendyfi:local
```

Optional run with persistent data/certs:

```bash
docker run -d --name mendyfi \
    -p 3000:3000 \
    -p 1812:1812/udp \
    -p 1813:1813/udp \
    -v mendyfi-data:/opt/mendyfi \
    mendyfi:local
```

Notes:

- The container generates `/opt/mendyfi/key.pem` and `/opt/mendyfi/cert.pem` automatically on startup.
- CN uses the first detected IP, and SAN includes detected public IP + LAN IPs.
- Useful env vars: `PUBLIC_IP`, `CERT_DAYS` (default `365`), `FORCE_REGENERATE_CERT=true`.

### Docker Compose

Run with compose:

```bash
cd docker
docker compose up -d --build
```

Stop:

```bash
cd docker
docker compose down
```

View logs:

```bash
cd docker
docker compose logs -f app
```

## Quick Start

1. Run the MendyFi app on your server or local device.
2. Make sure you know the IP address of that device.
3. Open the frontend and log in using your account format.

## Admin Login

Login page: http://lite.waspradi.us/login

Default admin credentials:

- Username format: `admin@<your_server_ip>`
- Password: `admin12345`

Example:

- Username: `admin@192.168.88.154`
- Password: `admin12345`

## Reseller Login

Reseller login page: http://lite.waspradi.us/reseller/login

Reseller credential format:

- Username format: `<reseller_username>@<your_server_ip>`
- Password: Set from the reseller page in your panel

## Notes

- The backend stays on your own device.
- The web frontend is only used for management.
- This app is free. You can send feature suggestions or report bugs/issues to help improve the system.

## Setup Tutorials (MikroTik)

- Enable RADIUS on MikroTik: see [`RADIUS SETTINGS.md`](https://github.com/mendylivium/mendyfi/blob/master/RADIUS%20SETTINGS.md)
- Create vouchers and set NAS ID: see [`GENERATING VOUCHER.md`](https://github.com/mendylivium/mendyfi/blob/master/GENERATING%20VOUCHER.md)
