/**
 * Startup configuration checks.
 *
 * The multisession rollout needs two shared secrets:
 *   - SESSION_SECRET signs the candidate cookie
 *   - INTERNAL_TOKEN authenticates service-to-service asset downloads
 *
 * A missing/weak secret in production is a security bug, not a warning, so
 * fail fast before the HTTP listener starts. Development keeps the random
 * per-process fallback so `npm run dev` works without extra setup.
 */

const config = require('../config');
const logger = require('./logger');

const MIN_SESSION_SECRET_LENGTH = 32;
const MIN_INTERNAL_TOKEN_LENGTH = 16;

function isProduction() {
  return config.env === 'prod' || config.env === 'production';
}

/**
 * Throw when the multisession configuration is unsafe for production.
 */
function validateConfig() {
  if (!config.multisession.enabled) return;

  const problems = [];

  if (isProduction()) {
    if (config.multisession.sessionSecret) {
      if (config.multisession.sessionSecret.length < MIN_SESSION_SECRET_LENGTH) {
        problems.push(
          `SESSION_SECRET must be at least ${MIN_SESSION_SECRET_LENGTH} characters ` +
          '(generate with: openssl rand -hex 32)'
        );
      }
    } else {
      problems.push(
        'SESSION_SECRET is required when MULTISESSION_ENABLED=true in production ' +
        '(generate with: openssl rand -hex 32)'
      );
    }

    if (config.multisession.internalToken) {
      if (config.multisession.internalToken.length < MIN_INTERNAL_TOKEN_LENGTH) {
        problems.push(
          `INTERNAL_TOKEN must be at least ${MIN_INTERNAL_TOKEN_LENGTH} characters ` +
          '(generate with: openssl rand -hex 32)'
        );
      }
    } else {
      problems.push(
        'INTERNAL_TOKEN is required when MULTISESSION_ENABLED=true in production ' +
        '(generate with: openssl rand -hex 32)'
      );
    }
  }

  if (problems.length > 0) {
    throw new Error(`Invalid multisession configuration:\n- ${problems.join('\n- ')}`);
  }

  if (!isProduction()) {
    if (!config.multisession.sessionSecret) {
      logger.warn('SESSION_SECRET is not set; using a random per-process secret (sessions will not survive a restart)');
    } else if (config.multisession.sessionSecret.length < MIN_SESSION_SECRET_LENGTH) {
      logger.warn(`SESSION_SECRET is shorter than ${MIN_SESSION_SECRET_LENGTH} characters; production will refuse to start`);
    }

    if (!config.multisession.internalToken) {
      logger.warn('INTERNAL_TOKEN is not set; per-session jumphosts cannot download exam assets');
    } else if (config.multisession.internalToken.length < MIN_INTERNAL_TOKEN_LENGTH) {
      logger.warn(`INTERNAL_TOKEN is shorter than ${MIN_INTERNAL_TOKEN_LENGTH} characters; production will refuse to start`);
    }
  }
}

module.exports = {
  validateConfig
};
