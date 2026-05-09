[Unit]
Description=Hugo MCP Server
After=network.target

[Service]
Type=simple
User=__USER__
Group=__GROUP__
WorkingDirectory=__WORK_DIR__
EnvironmentFile=__WORK_DIR__/.env
ExecStart=__WORK_DIR__/venv/bin/uvicorn main:app --host 0.0.0.0 --port __PORT__ --ssl-keyfile __WORK_DIR__/tls/server.key --ssl-certfile __WORK_DIR__/tls/server.crt
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=true
PrivateDevices=true
ReadWritePaths=__WORK_DIR__ __HUGO_SITE__

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

UMask=0077
LimitNOFILE=4096
TasksMax=64
MemoryMax=256M

[Install]
WantedBy=multi-user.target
