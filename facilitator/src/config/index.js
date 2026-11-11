require('dotenv').config();

const config = {
  port: process.env.PORT || 3000,
  env: process.env.NODE_ENV || 'development',
  
  ssh: {
    host: process.env.SSH_HOST || 'jumphost',
    port: parseInt(process.env.SSH_PORT || '22', 10),
    username: process.env.SSH_USERNAME || 'candidate',
    // Password is optional as jumphost allows passwordless authentication
    password: process.env.SSH_PASSWORD,
    privateKeyPath: process.env.SSH_PRIVATE_KEY_PATH,
  },
  
  logging: {
    level: process.env.LOG_LEVEL || 'info',
  },

  remoteDesktop: {
    host: process.env.REMOTE_DESKTOP_HOST || 'remote-desktop',
    port: process.env.REMOTE_DESKTOP_PORT || 5000
  },

  // Multisession support is rolled out behind a flag so the existing
  // single-environment flow keeps working until the data-plane rollout lands.
  multisession: {
    enabled: process.env.MULTISESSION_ENABLED === 'true',
    maxSessions: parseInt(process.env.MAX_SESSIONS || '3', 10),
    sessionSecret: process.env.SESSION_SECRET || '',
    internalToken: process.env.INTERNAL_TOKEN || '',
    facilitatorUrl: process.env.FACILITATOR_URL || 'http://facilitator:3000',
    sessionImageTag: process.env.SESSION_IMAGE_TAG || 'latest',
    // Hard upper bound for a session and its Redis record.
    sessionTtlSeconds: parseInt(process.env.SESSION_TTL_SECONDS || '28800', 10),
    // Reap a session with no API/heartbeat activity for this long.
    sessionIdleSeconds: parseInt(process.env.SESSION_IDLE_SECONDS || '1800', 10),
    // How often the reaper checks for idle/hard-expired sessions.
    sessionSweepIntervalSeconds: parseInt(process.env.SESSION_SWEEP_INTERVAL_SECONDS || '60', 10),
    // Bearer token for the admin session listing. Falls back to INTERNAL_TOKEN
    // so a deployment only needs one extra secret.
    adminToken: process.env.ADMIN_TOKEN || process.env.INTERNAL_TOKEN || '',
    controlNetwork: process.env.SESSION_CONTROL_NETWORK || 'ckx-sessions'
  },
};

module.exports = config; 