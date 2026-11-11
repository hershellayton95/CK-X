/**
 * In-process session metrics.
 *
 * The facilitator is a single process, so a small in-memory registry is enough
 * to expose counts and provision durations through the admin session endpoint.
 * Nothing here contains candidate data: only session IDs are logged elsewhere.
 */

const counters = {
  created: 0,
  destroyed: 0,
  failed: 0,
  expired: 0
};

const provisionDuration = {
  count: 0,
  totalMs: 0,
  maxMs: 0
};

let activeSessions = 0;

function recordSessionCreated() {
  counters.created += 1;
}

function recordSessionDestroyed() {
  counters.destroyed += 1;
}

function recordSessionFailed() {
  counters.failed += 1;
}

function recordSessionExpired() {
  counters.expired += 1;
}

/**
 * Record how long provisioning a session environment took
 * @param {number} durationMs
 */
function recordProvisionDuration(durationMs) {
  if (!Number.isFinite(durationMs) || durationMs < 0) return;

  provisionDuration.count += 1;
  provisionDuration.totalMs += durationMs;
  provisionDuration.maxMs = Math.max(provisionDuration.maxMs, durationMs);
}

/**
 * Update the concurrent-session gauge.
 * @param {number} count
 */
function setActiveSessions(count) {
  if (Number.isFinite(count) && count >= 0) activeSessions = count;
}

/**
 * Snapshot for the admin endpoint. Averaged values are rounded to whole ms.
 * @returns {Object}
 */
function snapshot() {
  const average = provisionDuration.count > 0
    ? Math.round(provisionDuration.totalMs / provisionDuration.count)
    : 0;

  return {
    activeSessions,
    sessionsCreated: counters.created,
    sessionsDestroyed: counters.destroyed,
    sessionsFailed: counters.failed,
    sessionsExpired: counters.expired,
    provisionDurationMs: {
      count: provisionDuration.count,
      average,
      max: provisionDuration.maxMs
    }
  };
}

/**
 * Test helper: reset all counters and the gauge.
 */
function reset() {
  counters.created = 0;
  counters.destroyed = 0;
  counters.failed = 0;
  counters.expired = 0;
  provisionDuration.count = 0;
  provisionDuration.totalMs = 0;
  provisionDuration.maxMs = 0;
  activeSessions = 0;
}

module.exports = {
  recordSessionCreated,
  recordSessionDestroyed,
  recordSessionFailed,
  recordSessionExpired,
  recordProvisionDuration,
  setActiveSessions,
  snapshot,
  reset
};
