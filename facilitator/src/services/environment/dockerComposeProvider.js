/**
 * Docker Compose environment provider.
 *
 * Runs one Compose project per candidate session (`ckx-<session-id>`) using
 * facilitator/docker-compose.session.yaml. Requires the facilitator container
 * to have the Docker CLI, the compose plugin, and the host Docker socket.
 */

const { execFile } = require('child_process');
const { promisify } = require('util');
const fs = require('fs');
const os = require('os');
const path = require('path');
const config = require('../../config');
const logger = require('../../utils/logger');

const execFileAsync = promisify(execFile);

const COMPOSE_FILE_CANDIDATES = [
  process.env.SESSION_COMPOSE_FILE,
  path.resolve(__dirname, '../../../docker-compose.session.yaml'),
  path.resolve(process.cwd(), 'docker-compose.session.yaml')
].filter(Boolean);

const MANAGED_LABEL = 'ckx.managed=true';
const SESSION_LABEL = 'ckx.session';

function composeFile() {
  const found = COMPOSE_FILE_CANDIDATES.find(candidate => fs.existsSync(candidate));
  if (!found) {
    throw new Error(
      `Session compose file not found. Looked in: ${COMPOSE_FILE_CANDIDATES.join(', ')}`
    );
  }
  return found;
}

function projectName(sessionId) {
  return `ckx-${sessionId}`;
}

/**
 * k3d rejects cluster names longer than 32 characters, and `ckx-<uuid>` is 40.
 * The name only has to be unique inside the session's own Docker daemon, so a
 * 12-hex-character suffix is enough; the kubeconfig context becomes
 * `ckx-<12 hex>` and still differs between sessions.
 */
function clusterName(sessionId) {
  return `ckx-${sessionId.replace(/-/g, '').slice(0, 12)}`;
}

function networkName(sessionId) {
  return `ckx-${sessionId}-net`;
}

function volumeName(sessionId) {
  return `ckx-${sessionId}-kube`;
}

function containerName(sessionId, service) {
  return `ckx-${sessionId}-${service}`;
}

/**
 * Environment for `docker compose` interpolation. Only the fields the session
 * compose file references are relevant.
 */
function composeEnv({ sessionId, vncPassword, terminalPassword }) {
  return {
    ...process.env,
    SESSION_ID: sessionId,
    SESSION_CLUSTER_NAME: clusterName(sessionId),
    SESSION_IMAGE_TAG: config.multisession.sessionImageTag,
    FACILITATOR_URL: config.multisession.facilitatorUrl,
    INTERNAL_TOKEN: config.multisession.internalToken || '',
    SESSION_CONTROL_NETWORK: config.multisession.controlNetwork,
    VNC_PASSWORD: vncPassword || '',
    TERMINAL_PASSWORD: terminalPassword || ''
  };
}

async function execDocker(args, options = {}) {
  const {
    env = process.env,
    timeout = 120000,
    ignoreErrors = false
  } = options;

  logger.debug(`docker ${args.join(' ')}`);

  try {
    const { stdout, stderr } = await execFileAsync('docker', args, {
      env,
      timeout,
      maxBuffer: 16 * 1024 * 1024
    });

    if (stderr && stderr.trim()) logger.debug(`docker stderr: ${stderr.trim()}`);
    return { stdout: stdout || '', stderr: stderr || '', failed: false };
  } catch (error) {
    const detail = String(error.stderr || error.stdout || error.message || '').trim();

    if (ignoreErrors) {
      logger.debug(`docker ${args.join(' ')} ignored failure: ${detail}`);
      return { stdout: '', stderr: detail, failed: true };
    }

    throw new Error(`docker ${args.join(' ')} failed: ${detail}`);
  }
}

async function composeDown(sessionId, vncPassword) {
  return execDocker(
    ['compose', '-p', projectName(sessionId), '-f', composeFile(), 'down', '-v', '--remove-orphans'],
    { env: composeEnv({ sessionId, vncPassword }), timeout: 180000, ignoreErrors: true }
  );
}

/**
 * Best-effort: attach the facilitator container to the session network so it
 * can SSH to the jumphost and serve as the jumphost asset URL.
 */
function selfContainer() {
  return process.env.SELF_CONTAINER_NAME || process.env.HOSTNAME || os.hostname();
}

async function connectSelfToNetwork(network) {
  const self = selfContainer();
  const result = await execDocker(
    ['network', 'connect', '--alias', 'facilitator', network, self],
    { ignoreErrors: true }
  );
  if (result.failed) {
    logger.warn(`Could not attach facilitator (${self}) to ${network}; SSH to the jumphost will fail unless the network is reachable another way`);
  }
}

async function disconnectSelfFromNetwork(network) {
  await execDocker(['network', 'disconnect', network, selfContainer()], { ignoreErrors: true });
}

/**
 * Ensure the shared control network exists. The root compose creates it, but
 * the facilitator also runs standalone in tests, and `docker compose up` fails
 * fast if an external network is missing.
 */
async function ensureControlNetwork() {
  const network = config.multisession.controlNetwork;
  const existing = await execDocker(['network', 'inspect', network], { ignoreErrors: true });
  if (!existing.failed) return;

  const created = await execDocker(
    ['network', 'create', '--label', 'ckx.control=true', network],
    { ignoreErrors: true }
  );
  if (created.failed) {
    logger.warn(`Could not create control network ${network}: ${created.stderr}`);
  } else {
    logger.info(`Created shared control network ${network}`);
  }
}

/**
 * Create the data plane for one session
 * @param {Object} spec
 * @param {string} spec.sessionId
 * @param {string} spec.examId
 * @param {string} spec.vncPassword
 * @param {string} [spec.terminalPassword]
 * @returns {Promise<Object>} env descriptor stored on the session
 */
async function createSession({ sessionId, examId, vncPassword, terminalPassword }) {
  const project = projectName(sessionId);
  const file = composeFile();
  const env = composeEnv({ sessionId, vncPassword, terminalPassword });

  logger.info(`Provisioning session environment ${project} (exam ${examId})`);

  await ensureControlNetwork();

  // A retry after a partial failure must not collide with leftover containers.
  await composeDown(sessionId, vncPassword);

  await execDocker(
    ['compose', '-p', project, '-f', file, 'up', '-d', '--wait', '--remove-orphans'],
    { env, timeout: 15 * 60 * 1000 }
  );

  await connectSelfToNetwork(networkName(sessionId));

  logger.info(`Session environment ${project} is ready`);

  return {
    provider: 'docker-compose',
    project,
    composeFile: file,
    network: networkName(sessionId),
    clusterName: clusterName(sessionId),
    jumphostHost: containerName(sessionId, 'jumphost'),
    remoteDesktopHost: containerName(sessionId, 'remote-desktop'),
    remoteDesktopPort: 6901,
    remoteTerminalHost: containerName(sessionId, 'remote-terminal'),
    remoteTerminalPort: 22,
    vncPassword,
    remoteTerminalPassword: terminalPassword || null,
    createdAt: new Date().toISOString()
  };
}

/**
 * Remove a session environment. Tolerant of partially created stacks.
 * @param {Object} session - Session record with optional env
 */
async function destroySession(session) {
  const sessionId = session.id;
  const vncPassword = session.env && session.env.vncPassword;

  logger.info(`Destroying session environment ${projectName(sessionId)}`);

  await disconnectSelfFromNetwork(networkName(sessionId));
  await composeDown(sessionId, vncPassword);

  // `compose down` can leave the network/volume behind if the project was only
  // partially created; clean by name as well.
  await execDocker(['network', 'rm', networkName(sessionId)], { ignoreErrors: true });
  await execDocker(['volume', 'rm', volumeName(sessionId)], { ignoreErrors: true });
}

/**
 * Remove anything left over from an interrupted destroy.
 * @param {string} sessionId
 */
async function destroyById(sessionId) {
  logger.warn(`Removing orphaned environment for session ${sessionId}`);

  await disconnectSelfFromNetwork(networkName(sessionId));
  await composeDown(sessionId, null);

  const containers = await execDocker(
    ['ps', '-aq', '--filter', `label=${SESSION_LABEL}=${sessionId}`],
    { ignoreErrors: true }
  );
  const containerIds = containers.stdout.split('\n').map(line => line.trim()).filter(Boolean);
  if (containerIds.length > 0) {
    await execDocker(['rm', '-f', ...containerIds], { ignoreErrors: true });
  }

  const volumes = await execDocker(
    ['volume', 'ls', '-q', '--filter', `label=${SESSION_LABEL}=${sessionId}`],
    { ignoreErrors: true }
  );
  const volumeIds = volumes.stdout.split('\n').map(line => line.trim()).filter(Boolean);
  if (volumeIds.length > 0) {
    await execDocker(['volume', 'rm', '-f', ...volumeIds], { ignoreErrors: true });
  }

  const networks = await execDocker(
    ['network', 'ls', '-q', '--filter', `label=${SESSION_LABEL}=${sessionId}`],
    { ignoreErrors: true }
  );
  const networkIds = networks.stdout.split('\n').map(line => line.trim()).filter(Boolean);
  if (networkIds.length > 0) {
    await execDocker(['network', 'rm', ...networkIds], { ignoreErrors: true });
  }

  // Label filters already cover the managed stack; these catch name-only
  // leftovers from a stack whose labels were removed.
  await execDocker(['network', 'rm', networkName(sessionId)], { ignoreErrors: true });
  await execDocker(['volume', 'rm', volumeName(sessionId)], { ignoreErrors: true });
}

/**
 * Remove environments whose session no longer exists in Redis.
 * @param {string[]} activeSessionIds
 * @returns {Promise<{removed: string[], kept: string[]}>}
 */
async function reconcile(activeSessionIds = []) {
  const active = new Set(activeSessionIds);
  const listed = await execDocker(
    ['ps', '-a', '--filter', `label=${MANAGED_LABEL}`, '--format', `{{.Label "${SESSION_LABEL}"}}`],
    { ignoreErrors: true }
  );

  const discovered = [...new Set(
    listed.stdout.split('\n').map(line => line.trim()).filter(Boolean)
  )];

  const removed = [];
  const kept = [];

  for (const sessionId of discovered) {
    if (active.has(sessionId)) {
      kept.push(sessionId);
      continue;
    }

    try {
      await destroyById(sessionId);
      removed.push(sessionId);
    } catch (error) {
      logger.error(`Failed to remove orphaned environment ${sessionId}`, { error: error.message });
    }
  }

  if (removed.length > 0) {
    logger.debug(`Reconciled ${removed.length} orphaned session environment(s)`);
  }

  return { removed, kept };
}

module.exports = {
  name: 'docker-compose',
  createSession,
  destroySession,
  destroyById,
  reconcile,
  // Exposed for tests/troubleshooting
  projectName,
  networkName,
  volumeName,
  containerName
};
