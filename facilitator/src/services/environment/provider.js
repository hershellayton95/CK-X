/**
 * Environment provider interface / factory.
 *
 * A provider owns the lifecycle of the per-session data plane (Kubernetes
 * cluster host, jumphost, desktop, terminal). The facilitator talks only to
 * this interface so a future Kubernetes provider can replace the local Docker
 * Compose one.
 *
 * Required methods:
 *   createSession({ sessionId, examId, vncPassword }) -> Promise<env>
 *   destroySession(session) -> Promise<void>
 *   reconcile(activeSessionIds) -> Promise<{removed: string[], kept: string[]}>
 *
 * `env` is persisted on the session record and must contain at least:
 *   { project, network, clusterName, jumphostHost,
 *     remoteDesktopHost, remoteTerminalHost, vncPassword }
 */

const logger = require('../../utils/logger');

const PROVIDERS = {
  'docker-compose': () => require('./dockerComposeProvider')
};

/**
 * Resolve the configured environment provider
 * @returns {{createSession: Function, destroySession: Function, reconcile: Function, name: string}}
 */
function getProvider() {
  const name = process.env.ENV_PROVIDER || 'docker-compose';
  const factory = PROVIDERS[name];

  if (!factory) {
    logger.error(`Unknown ENV_PROVIDER "${name}"`);
    throw new Error(`Unsupported environment provider: ${name}`);
  }

  return factory();
}

module.exports = {
  getProvider
};
