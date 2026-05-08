# Hugo MCP — nginx vhost
# Add to /etc/nginx/sites-available/__DOMAIN__ then symlink to sites-enabled/
# After: nginx -t && systemctl reload nginx

server {
    listen 443 ssl http2;
    server_name __DOMAIN__;

    # SSL — uncomment and adapt one of the following:
    # ssl_certificate     /etc/letsencrypt/live/__DOMAIN__/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/__DOMAIN__/privkey.pem;
    # ssl_certificate     /etc/cloudflare/cert.pem;
    # ssl_certificate_key /etc/cloudflare/key.pem;

    # Proxy to Hugo MCP on loopback
    location /mcp {
        proxy_pass http://127.0.0.1:__PORT__;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        # Timeouts for MCP long-polling
        proxy_read_timeout 300s;
        proxy_send_timeout 60s;

        client_max_body_size 1m;
        client_body_timeout 10s;
    }

    # Block monitoring endpoints from outside
    location ~ ^/(healthz|readyz|metrics)$ {
        deny all;
    }

    # Drop everything else silently
    location / {
        return 444;
    }
}

server {
    listen 80;
    server_name __DOMAIN__;
    return 301 https://$host$request_uri;
}
