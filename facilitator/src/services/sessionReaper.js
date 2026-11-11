/**
 * Session reaper
 *
 * Enforces the two session bounds:
 *   - idle timeout: no API/heartbeat activity for SESSION_IDLE_SECONDS
 *   - hard TTL: the fixed expiresAt stored on the session record
 *
 * Reaping tears down the per-session data plane, deletes the exam data, then
 * removes the session record so the slot is reusable. A reconciliation pass
 * afterwards sweeps up stacks whose teardown failed or that were left behind
 * by a crash.
 */

const config = require('../config');
const sessionService = require('./sessionService');
const environmentService = require('./environmentService');
const redisClient = require('../utils/redisClient');
const logger = require('../utils/logger');
const metrics = require('../utils/sessionMetrics');

const REAPER_LOCK = 'session:reaper:lock';

let timer = null;
let sweeping = false;

/**
 * Remove the exam data owned by an expired session
 * @param {Object} session
 */
async function cleanupExamData(session) {
  if (!session.examId) return;

  try {
    const currentExamId = await redisClient.getCurrentExamId();
    if (currentExamId === session.examId) {
      await redisClient.deleteCurrentExamId();
    }
    await redisClient.deleteAllExamData(session.examId);
  } catch (error) {
    logger.error(`Failed to delete exam data for expired session ${session.id}`, {
      sessionId: session.id,
      examId: session.examId,
      error: error.message
    });
  }
}

/**
 * Tear down and delete one session. The record is removed even when teardown
 * fails so the slot is not held forever; the reconciliation pass retries the
 * stack by Docker label on the next sweep.
 * @param {Object} session
 * @param {'idle'|'expired'} reason
 */
async function reapSession(session, reason) {
  logger.warn(`Reaping ${reason} session ${session.id}`, {
    sessionId: session.id,
    examId: session.examId || null,
    reason,
    lastSeenAt: session.lastSeenAt,
    expiresAt: session.expiresAt || null
  });

  try {
    await environmentService.destroyForSession(session);
  } catch (error) {
    metrics.recordSessionFailed();
    logger.error(`Reaper could not destroy environment for session ${session.id}`, {
      sessionId: session.id,
      error: error.message
    });
  }

  await cleanupExamData(session);
  await sessionService.deleteSession(session.id);
  metrics.recordSessionExpired();
}

/**
 * Decide why a session should be reaped, if at all.
 * @param {Object} session
 * @param {number} now
 * @returns {'idle'|'expired'|null}
 */
function reapReason(session, now) {
  const expiresAt = Date.parse(session.expiresAt || '');
  if (Number.isFinite(expiresAt) && now >= expiresAt) return 'expired';

  const idleMs = config.multisession.sessionIdleSeconds * 1000;
  if (idleMs <= 0) return null;

  const lastSeen = Date.parse(session.lastSeenAt || session.createdAt || '');
  if (!Number.isFinite(lastSeen)) return null;

  return now - lastSeen >= idleMs ? 'idle' : null;
}

/**
 * One reaper pass.
 * @returns {Promise<{skipped?: boolean, idle: string[], expired: string[], removed: string[], errors: string[]}>}
 */
async function sweep() {
  const result = { idle: [], expired: [], removed: [], errors: [] };

  if (sweeping) return { ...result, skipped: true };

  const client = await redisClient.getClient();
  const owner = `${process.pid}:${Date.now()}`;
  // Teardown of several stacks can take minutes; keep the lock long enough and
  // release it compare-and-delete style so an expired lock cannot be stolen.
  const lockTtl = Math.max(300, config.multisession.sessionSweepIntervalSeconds * 2);
  const acquired = await client.set(REAPER_LOCK, owner, { NX: true, EX: lockTtl });
  if (acquired !== 'OK') {
    logger.debug('Skipping reaper sweep: another sweep is running');
    return { ...result, skipped: true };
  }

  sweeping = true;

  try {
    const sessions = await sessionService.listSessions();
    const now = Date.now();

    for (const session of sessions) {
      const reason = reapReason(session, now);
      if (!reason) continue;

      try {
        await reapSession(session, reason);
        result[reason].push(session.id);
      } catch (error) {
        result.errors.push(session.id);
        logger.error(`Failed to reap session ${session.id}`, {
          sessionId: session.id,
          error: error.message
        });
      }
    }

    const reconciled = await environmentService.reconcile();
    result.removed = reconciled.removed;
  } catch (error) {
    logger.error(`Session reaper sweep failed: ${error.message}`);
  } finally {
    sweeping = false;
    try {
      await client.eval(
        "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end",
        { keys: [REAPER_LOCK], arguments: [owner] }
      );
    } catch (error) {
      logger.debug(`Could not release reaper lock: ${error.message}`);
    }

    try {
      metrics.setActiveSessions(await sessionService.countActiveSessions());
    } catch (error) {
      logger.debug(`Could not refresh active session gauge: ${error.message}`);
    }
  }

  if (result.idle.length || result.expired.length || result.removed.length) {
    logger.info(
      `Reaper: ${result.idle.length} idle, ${result.expired.length} expired, ` +
      `${result.removed.length} orphaned environment(s) removed`,
      {
        idleSessions: result.idle,
        expiredSessions: result.expired,
        removedEnvironments: result.removed
      }
    );
  }

  return result;
}

/**
 * Start the periodic sweep.
 */
function start() {
  if (timer || !config.multisession.enabled) return;

  const intervalMs = Math.max(1, config.multisession.sessionSweepIntervalSeconds) * 1000;
  timer = setInterval(() => {
    sweep().catch(error => logger.error(`Session reaper error: ${error.message}`));
  }, intervalMs);

  // Do not keep the process alive just for the reaper (tests, tooling).
  if (typeof timer.unref === 'function') timer.unref();

  logger.info(`Session reaper started (every ${intervalMs / 1000}s)`, {
    idleTimeoutSeconds: config.multisession.sessionIdleSeconds,
    hardTtlSeconds: config.multisession.sessionTtlSeconds
  });
}

/**
 * Stop the periodic sweep.
 */
function stop() {
  if (!timer) return;
  clearInterval(timer);
  timer = null;
  logger.info('Session reaper stopped');
}

module.exports = {
  start,
  stop,
  sweep,
  reapReason
};
