/**
 * Environment Service
 *
 * Orchestrates per-session data-plane provisioning: creates the Docker Compose
 * stack, stores its connection details on the session, then runs the jumphost
 * preparation for the owning exam.
 */

const crypto = require('crypto');
const sessionService = require('./sessionService');
const jumphostService = require('./jumphostService');
const redisClient = require('../utils/redisClient');
const { getProvider } = require('./environment/provider');
const logger = require('../utils/logger');
const metrics = require('../utils/sessionMetrics');
const { machineHostname } = require('../utils/machineHostname');

/**
 * Generate the per-session VNC password
 * @returns {string}
 */
function generateVncPassword() {
  return crypto.randomBytes(18).toString('base64url');
}

// Password for the browser terminal container. Random per session so a shell
// inside one session cannot log into another session's terminal over the
// shared control network.
function generateTerminalPassword() {
  return crypto.randomBytes(18).toString('base64url');
}

/**
 * Provision the environment for a newly created exam
 * @param {string} sessionId
 * @param {string} examId
 * @param {number} [nodeCount=1]
 * @returns {Promise<Object>} jumphostService result shape
 */
async function provisionForExam(sessionId, examId, nodeCount = 1) {
  const session = await sessionService.getSession(sessionId);
  if (!session) {
    throw new Error(`Cannot provision environment: session ${sessionId} not found`);
  }

  const provider = getProvider();
  const vncPassword = generateVncPassword();
  const terminalPassword = generateTerminalPassword();
  const startedAt = Date.now();
  let env;

  try {
    env = await provider.createSession({
      sessionId,
      examId,
      vncPassword,
      terminalPassword,
      // CKA candidates get cka9999, CKAD candidates ckad9999, etc.
      machineHostname: machineHostname(session.category)
    });
  } catch (error) {
    metrics.recordSessionFailed();
    logger.error(`Failed to create environment for exam ${examId}`, {
      sessionId,
      examId,
      error: error.message
    });
    await redisClient.persistExamStatus(examId, 'PREPARATION_FAILED');
    await sessionService.updateSession(sessionId, { status: 'PREPARATION_FAILED' });
    throw error;
  }

  await sessionService.updateSession(sessionId, { env, status: 'PREPARING' });

  const result = await jumphostService.setupExamEnvironment(examId, nodeCount, {
    env,
    skipVncRestart: true
  });

  if (!result.success) {
    metrics.recordSessionFailed();
    logger.error(`Jumphost preparation failed for exam ${examId}; destroying environment`, {
      sessionId,
      examId
    });
    try {
      await provider.destroySession(await sessionService.getSession(sessionId));
    } catch (destroyError) {
      logger.error(`Failed to destroy environment after preparation failure`, {
        sessionId,
        error: destroyError.message
      });
    }

    await sessionService.updateSession(sessionId, { env: null, status: 'PREPARATION_FAILED' });
    return result;
  }

  const examStatus = await redisClient.getExamStatus(examId);
  await sessionService.updateSession(sessionId, { status: examStatus || 'READY' });

  const durationMs = Date.now() - startedAt;
  metrics.recordProvisionDuration(durationMs);
  logger.info(`Session ${sessionId} environment ready for exam ${examId}`, {
    sessionId,
    examId,
    durationMs
  });

  return result;
}

/**
 * Destroy the environment owned by a session
 * @param {Object} session
 * @returns {Promise<void>}
 */
async function destroyForSession(session) {
  if (!session || !session.id) return;

  const provider = getProvider();

  try {
    await provider.destroySession(session);
  } catch (error) {
    metrics.recordSessionFailed();
    logger.error(`Failed to destroy environment for session ${session.id}`, {
      sessionId: session.id,
      error: error.message
    });
    throw error;
  }

  await sessionService.updateSession(session.id, { env: null, status: 'DESTROYED' });
  metrics.recordSessionDestroyed();
  logger.info(`Destroyed environment for session ${session.id}`, { sessionId: session.id });
}

/**
 * Remove data-plane stacks that have no live session in Redis
 * @returns {Promise<{removed: string[], kept: string[]}>}
 */
async function reconcile() {
  const provider = getProvider();
  const sessions = await sessionService.listSessions();
  const result = await provider.reconcile(sessions.map(session => session.id));

  if (result.removed.length > 0) {
    logger.info(`Removed ${result.removed.length} orphaned session environment(s)`, {
      sessionIds: result.removed
    });
  }

  return result;
}

module.exports = {
  provisionForExam,
  destroyForSession,
  reconcile
};
