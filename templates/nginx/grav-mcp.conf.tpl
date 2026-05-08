# Grav MCP — nginx location block
# Add this location block inside your existing Grav server{} block
# After: nginx -t && systemctl reload nginx

    # MCP endpoint — proxied through PHP-FPM by Grav's router
    location /api/mcp {
        # Grav handles this via its router — no special proxy needed.
        # Ensure your Grav vhost already has a working PHP-FPM location.
        # This block just documents the endpoint; Grav's index.php catch-all serves it.
        try_files $uri $uri/ /index.php?$query_string;

        # Timeouts for MCP requests
        fastcgi_read_timeout 120s;

        # Restrict to authenticated clients only (Bearer token checked by Grav plugin)
        # No IP restriction here — authentication is handled at the application level.
    }

# Note: The /api/mcp route is served by Grav's existing PHP-FPM configuration.
# Verify Grav's catch-all PHP location includes index.php handling, e.g.:
#
#   location / {
#       try_files $uri $uri/ /index.php?$query_string;
#   }
#   location ~ \.php$ {
#       fastcgi_pass unix:/run/php/php8.x-fpm.sock;
#       include fastcgi_params;
#       fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
#   }
