/**
 * Session middleware
 *
 * When MULTISESSION_ENABLED is false every helper is a pass-through so the
 * existing single-environment behavior is untouched (feature-flag rollback).
 */

const config = require('../config');
const crypto = require('crypto');
const logger = require('../utils/logger');
const sessionService = require('../services/sessionService');
const sessionCookie = require('../utils/sessionCookie');

function multisessionEnabled() {
  return config.multisession.enabled;
}

/**
 * Compare the request's internal token without leaking timing information
 * @param {Object} req
 * @returns {boolean}
 */
function hasValidInternalToken(req) {
  const expected = config.multisession.internalToken;
  const provided = req.headers['x-internal-token'];
  if (!expected || !provided) return false;

  const a = Buffer.from(String(provided));
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

/**
 * Load the candidate's session from the signed cookie into req.session
 */
async function attachSession(req, res, next) {
  if (!multisessionEnabled()) return next();

  try {
    const sessionId = sessionCookie.getSessionIdFromRequest(req);
    if (!sessionId) return next();

    const session = await sessionService.getSession(sessionId);
    if (!session) {
      logger.warn(`Cookie references unknown session ${sessionId}; clearing cookie`);
      sessionCookie.clearSessionCookie(req, res);
      return next();
    }

    req.session = await sessionService.touchSession(session);
    return next();
  } catch (error) {
    logger.error('Failed to attach session', { error: error.message });
    return next(error);
  }
}

/**
 * Reject requests without a live session
 */
function requireSession(req, res, next) {
  if (!multisessionEnabled()) return next();

  if (!req.session) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'No active session. Start a lab first.'
    });
  }

  return next();
}

/**
 * Ensure the session owns the exam referenced by req.params.examId
 * Also refuses session-less exam IDs when there is no exam yet.
 */
function requireExamOwnership(req, res, next) {
  if (!multisessionEnabled()) return next();

  // Service-to-service calls (the per-session jumphost downloads the assets
  // tarball) authenticate with a shared internal token instead of a cookie.
  if (hasValidInternalToken(req)) return next();

  if (!req.session) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'No active session. Start a lab first.'
    });
  }

  if (!req.session.examId) {
    return res.status(409).json({
      error: 'Conflict',
      message: 'Session has no exam yet. Start a lab first.'
    });
  }

  if (req.session.examId !== req.params.examId) {
    logger.warn(`Session ${req.session.id} attempted to access exam ${req.params.examId}`);
    return res.status(403).json({
      error: 'Forbidden',
      message: 'This exam belongs to another session.'
    });
  }

  return next();
}

module.exports = {
  multisessionEnabled,
  attachSession,
  requireSession,
  requireExamOwnership
};
