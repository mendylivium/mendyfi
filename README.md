# MendyFi RADIUS

MendyFi RADIUS is a lightweight RADIUS server app that is easier to set up than the original PHP-based version. You run the backend on your own device (Windows or Linux), then manage it using the web frontend.

Frontend URL: http://lite.waspradi.us

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

- Enable RADIUS on MikroTik: see `RADIUS SETTINGS.md`
- Create vouchers and set NAS ID: see `GENERATING VOUCHER.md`