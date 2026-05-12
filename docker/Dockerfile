FROM alpine:3.20

RUN apk add --no-cache ca-certificates openssl curl iproute2

WORKDIR /opt/mendyfi

COPY mendyfi-linux-amd64 /usr/local/bin/mendyfi
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /usr/local/bin/mendyfi /entrypoint.sh

EXPOSE 3000 1812/udp 1813/udp

ENTRYPOINT ["/entrypoint.sh"]