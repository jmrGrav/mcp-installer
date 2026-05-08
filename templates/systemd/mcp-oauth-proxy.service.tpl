[Unit]
Description=MCP OAuth Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=__USER__
Group=__GROUP__
WorkingDirectory=__WORK_DIR__
EnvironmentFile=__SECRETS_FILE__
ExecStart=__WORK_DIR__/venv/bin/python mcp_oauth_proxy.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ReadWritePaths=__WORK_DIR__ __AUDIT_LOG_DIR__

ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
ProtectHostname=true
ProtectProc=invisible
ProcSubset=pid

RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true
CapabilityBoundingSet=
AmbientCapabilities=

SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources
SystemCallErrorNumber=EPERM

# Network: loopback only (proxy calls backend on 127.0.0.1)
RestrictAddressFamilies=AF_INET AF_INET6
IPAddressDeny=any
IPAddressAllow=127.0.0.0/8
IPAddressAllow=::1/128

UMask=0077
LimitNOFILE=4096
TasksMax=64
MemoryMax=256M

[Install]
WantedBy=multi-user.target
