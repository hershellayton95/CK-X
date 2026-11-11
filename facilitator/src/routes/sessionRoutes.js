/**
 * Session routes
 *
 * `GET /api/v1/sessions/me` lets the webapp learn where the caller's desktop
 * and terminal containers live. Authentication is the same signed cookie the
 * browser uses for exam routes: the webapp forwards it, so no extra secret
 * needs to be shared. Returns 404 when multisession is disabled so the webapp
 * keeps its single-environment targets.
 */

const express = require('express');
const crypto = require('crypto');
const config = require('../config');
const sessionService = require('../services/sessionService');
const sessionMetrics = require('../utils/sessionMetrics');
const logger = require('../utils/logger');
const { attachSession } = require('../middleware/session');

const router = express.Router();

const SECRET_FIELD = /(password|token|secret)/i;

/**
 * Constant-time check of the admin token
 * @param {Object} req
 * @returns {boolean}
 */
function hasValidAdminToken(req) {
  const expected = config.multisession.adminToken;
  const provided = req.headers['x-admin-token'] || req.headers['x-internal-token'];
  if (!expected || !provided) return false;

  const a = Buffer.from(String(provided));
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

/**
 * Environment descriptors contain connection passwords; strip anything
 * secret-looking before returning them to an operator.
 * @param {Object|null} env
 * @returns {Object|null}
 */
function sanitizeEnv(env) {
  if (!env) return null;

  const safe = {};
  for (const [key, value] of Object.entries(env)) {
    if (SECRET_FIELD.test(key)) continue;
    safe[key] = value;
  }
  return safe;
}

router.get('/me', attachSession, (req, res) => {
  if (!config.multisession.enabled) {
    return res.status(404).json({
      error: 'Not Found',
      message: 'Multisession is disabled'
    });
  }

  if (!req.session) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'No active session. Start a lab first.'
    });
  }

  const env = req.session.env || {};

  return res.json({
    sessionId: req.session.id,
    examId: req.session.examId || null,
    status: req.session.status || null,
    env: {
      remoteDesktopHost: env.remoteDesktopHost || null,
      remoteDesktopPort: env.remoteDesktopPort || 6901,
      vncPassword: env.vncPassword || null,
      remoteTerminalHost: env.remoteTerminalHost || null,
      remoteTerminalPort: env.remoteTerminalPort || 22,
      remoteTerminalPassword: env.remoteTerminalPassword || null
    }
  });
});

/**
 * Admin: list live sessions and in-process metrics. Requires ADMIN_TOKEN
 * (falls back to INTERNAL_TOKEN); deliberately not cookie-authenticated.
 */
router.get('/', async (req, res) => {
  if (!hasValidAdminToken(req)) {
    logger.warn(`Rejected admin session list from ${req.ip}`);
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'A valid admin token is required'
    });
  }

  try {
    const liveSessions = await sessionService.listSessions();
    sessionMetrics.setActiveSessions(liveSessions.length);

    const sessions = liveSessions
      .sort((a, b) => String(a.createdAt).localeCompare(String(b.createdAt)))
      .map(session => ({
        id: session.id,
        status: session.status || null,
        examId: session.examId || null,
        labId: session.labId || null,
        labName: session.labName || null,
        category: session.category || null,
        createdAt: session.createdAt,
        lastSeenAt: session.lastSeenAt,
        expiresAt: session.expiresAt || null,
        env: sanitizeEnv(session.env)
      }));

    return res.json({
      count: sessions.length,
      maxSessions: config.multisession.maxSessions,
      idleTimeoutSeconds: config.multisession.sessionIdleSeconds,
      sweepIntervalSeconds: config.multisession.sessionSweepIntervalSeconds,
      sessions,
      metrics: sessionMetrics.snapshot()
    });
  } catch (error) {
    logger.error(`Failed to list sessions: ${error.message}`);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to list sessions'
    });
  }
});

module.exports = router;
