/**
 * Session Service
 *
 * Stores candidate sessions in Redis. A session owns exactly one exam and is
 * the unit of isolation for the multisession rollout: exam data stays keyed by
 * exam ID, while the "which exam is mine" pointer lives here instead of the
 * old global `current-exam-id` key.
 */

const { v4: uuidv4 } = require('uuid');
const redisClient = require('../utils/redisClient');
const logger = require('../utils/logger');
const metrics = require('../utils/sessionMetrics');
const config = require('../config');

const SESSION_PREFIX = 'session:';
const SESSION_INDEX = 'session:index';
const SPAWN_LOCK_PREFIX = 'session:lock:';
const SPAWN_LOCK_TTL = 30; // seconds

function sessionKey(sessionId) {
  return `${SESSION_PREFIX}${sessionId}`;
}

function sessionTtl() {
  return config.multisession.sessionTtlSeconds;
}

/**
 * Seconds left before the hard session deadline. Reads without a stored
 * expiresAt (pre-M6 records) fall back to a full TTL.
 * @param {Object} session
 * @returns {number}
 */
function remainingTtlSeconds(session) {
  const expiresAt = Date.parse((session && session.expiresAt) || '');
  if (!Number.isFinite(expiresAt)) return sessionTtl();
  return Math.ceil((expiresAt - Date.now()) / 1000);
}

/**
 * Create a session record
 * @param {Object} [data] - Initial session fields
 * @returns {Promise<Object>} The stored session
 */
async function createSession(data = {}) {
  const client = await redisClient.getClient();
  const now = Date.now();
  const nowIso = new Date(now).toISOString();
  const session = {
    id: uuidv4(),
    createdAt: nowIso,
    lastSeenAt: nowIso,
    status: 'CREATED',
    examId: null,
    env: null,
    ...data
  };

  // The hard deadline is fixed at creation; lastSeenAt only drives the idle
  // check in the reaper. Callers may supply expiresAt for tests/imports.
  if (!session.expiresAt) {
    session.expiresAt = new Date(now + sessionTtl() * 1000).toISOString();
  }

  // Honour an explicit shorter expiresAt, but never write past the hard cap.
  const ttl = Math.max(1, Math.min(sessionTtl(), remainingTtlSeconds(session)));

  await client.setEx(sessionKey(session.id), ttl, JSON.stringify(session));
  await client.sAdd(SESSION_INDEX, session.id);

  metrics.recordSessionCreated();
  logger.info(`Created session ${session.id}`, { sessionId: session.id });
  return session;
}

/**
 * Read a session record
 * @param {string} sessionId
 * @returns {Promise<Object|null>}
 */
async function getSession(sessionId) {
  if (!sessionId) return null;

  const client = await redisClient.getClient();
  const data = await client.get(sessionKey(sessionId));
  if (!data) return null;

  try {
    return JSON.parse(data);
  } catch (error) {
    logger.error(`Failed to parse session ${sessionId}: ${error.message}`, { sessionId });
    return null;
  }
}

/**
 * Refresh lastSeenAt and TTL at most once per minute to avoid a write per HTTP
 * call.
 * @param {Object} session
 * @returns {Promise<Object>} Potentially updated session
 */
async function touchSession(session) {
  if (!session || !session.id) return session;

  const now = Date.now();
  const lastSeen = Date.parse(session.lastSeenAt || 0) || 0;
  if (now - lastSeen < 60 * 1000) return session;

  return (await updateSession(session.id, { lastSeenAt: new Date(now).toISOString() })) || session;
}

/**
 * Merge fields into a session
 * @param {string} sessionId
 * @param {Object} patch
 * @returns {Promise<Object|null>} Updated session, or null when missing/expired
 */
async function updateSession(sessionId, patch = {}) {
  const session = await getSession(sessionId);
  if (!session) return null;

  const updated = { ...session, ...patch, id: session.id, createdAt: session.createdAt };
  if (!updated.expiresAt) {
    updated.expiresAt = new Date(Date.parse(updated.createdAt) + sessionTtl() * 1000).toISOString();
  }

  const ttl = remainingTtlSeconds(updated);
  if (ttl <= 0) {
    logger.warn(`Refusing to extend expired session ${sessionId}`, { sessionId });
    await deleteSession(sessionId);
    return null;
  }

  const client = await redisClient.getClient();
  // Never rewrite beyond the hard deadline: the TTL is always the time left,
  // clamped to the configured hard cap.
  await client.setEx(sessionKey(sessionId), Math.min(sessionTtl(), ttl), JSON.stringify(updated));
  return updated;
}

/**
 * Delete a session record
 * @param {string} sessionId
 * @returns {Promise<boolean>} True when something was removed
 */
async function deleteSession(sessionId) {
  if (!sessionId) return false;

  const client = await redisClient.getClient();
  const removed = await client.del(sessionKey(sessionId));
  await client.sRem(SESSION_INDEX, sessionId);

  if (removed) logger.info(`Deleted session ${sessionId}`, { sessionId });
  return removed > 0;
}

/**
 * List live sessions, pruning index entries whose payload expired
 * @returns {Promise<Array<Object>>}
 */
async function listSessions() {
  const client = await redisClient.getClient();
  const ids = await client.sMembers(SESSION_INDEX);
  if (ids.length === 0) return [];

  const sessions = [];
  const staleIds = [];

  for (const id of ids) {
    const session = await getSession(id);
    if (session) {
      sessions.push(session);
    } else {
      staleIds.push(id);
    }
  }

  if (staleIds.length > 0) {
    await client.sRem(SESSION_INDEX, staleIds);
    logger.debug(`Pruned ${staleIds.length} stale session index entries`);
  }

  return sessions;
}

/**
 * Count live sessions
 * @returns {Promise<number>}
 */
async function countActiveSessions() {
  return (await listSessions()).length;
}

/**
 * Decide whether a new session fits under MAX_SESSIONS
 * @returns {Promise<{admitted: boolean, active: number, max: number}>}
 */
async function admitSession() {
  const max = config.multisession.maxSessions;
  const active = await countActiveSessions();

  return {
    admitted: active < max,
    active,
    max
  };
}

/**
 * Best-effort lock around expensive environment provisioning (one per session)
 * @param {string} sessionId
 * @returns {Promise<boolean>}
 */
async function acquireSpawnLock(sessionId) {
  const client = await redisClient.getClient();
  const result = await client.set(`${SPAWN_LOCK_PREFIX}${sessionId}`, '1', {
    NX: true,
    EX: SPAWN_LOCK_TTL
  });
  return result === 'OK';
}

/**
 * Release the provisioning lock
 * @param {string} sessionId
 * @returns {Promise<void>}
 */
async function releaseSpawnLock(sessionId) {
  const client = await redisClient.getClient();
  await client.del(`${SPAWN_LOCK_PREFIX}${sessionId}`);
}

module.exports = {
  SESSION_PREFIX,
  SESSION_INDEX,
  sessionTtl,
  remainingTtlSeconds,
  createSession,
  getSession,
  touchSession,
  updateSession,
  deleteSession,
  listSessions,
  countActiveSessions,
  admitSession,
  acquireSpawnLock,
  releaseSpawnLock
};
