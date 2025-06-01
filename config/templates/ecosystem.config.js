module.exports = {
  apps: [{
    name: '${DOMAIN}',
    script: '${SCRIPT}',
    instances: 2,
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: ${PORT}
    },
    error_file: '/var/log/sites/${DOMAIN}/pm2-error.log',
    out_file: '/var/log/sites/${DOMAIN}/pm2-out.log',
    log_file: '/var/log/sites/${DOMAIN}/pm2-combined.log',
    time: true,
    max_memory_restart: '1G',
    autorestart: true,
    max_restarts: 10,
    min_uptime: '10s'
  }]
}
