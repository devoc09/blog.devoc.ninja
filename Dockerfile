FROM caddy:2.4.6-alpine

COPY Caddyfile /etc/caddy/Caddyfile
COPY public/ /blog/public
Volume caddy_data:/data
