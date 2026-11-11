/**
 * Session cookie helpers
 *
 * Cookies are signed with HMAC-SHA256 so a candidate cannot craft a session
 * identifier for somebody else's exam. The session ID itself is a random UUID
 * stored in Redis by sessionService.
 */

const crypto = require('crypto');
const config = require('../config');
const logger = require('../utils/logger');

const COOKIE_NAME = 'ckx_session';

// Fall back to a per-process secret if the operator did not configure one.
// Cookies then stop working after a restart, but development keeps working.
let secret = config.multisession.sessionSecret;
if (!secret) {
  secret = crypto.randomBytes(32).toString('hex');
  if (config.multisession.enabled) {
    logger.warn('SESSION_SECRET is not set; using a random per-process secret. Sessions will not survive a facilitator restart.');
  }
}

/**
 * Parse a Cookie header into a plain object
 * @param {string} [header]
 * @returns {Object}
 */
function parseCookies(header = '') {
  return String(header)
    .split(';')
    .map(part => part.trim())
    .filter(Boolean)
    .reduce((cookies, part) => {
      const separator = part.indexOf('=');
      if (separator === -1) return cookies;
      const name = part.slice(0, separator).trim();
      const value = part.slice(separator + 1).trim();
      try {
        cookies[name] = decodeURIComponent(value);
      } catch (error) {
        cookies[name] = value;
      }
      return cookies;
    }, {});
}

/**
 * Sign a session ID
 * @param {string} sessionId
 * @returns {string} base64url HMAC
 */
function signSessionId(sessionId) {
  return crypto.createHmac('sha256', secret).update(sessionId).digest('base64url');
}

/**
 * Verify a signed cookie value
 * @param {string} value - `<sessionId>.<signature>`
 * @returns {string|null} session ID when the signature is valid
 */
function verifyCookieValue(value) {
  if (typeof value !== 'string') return null;

  const separator = value.lastIndexOf('.');
  if (separator <= 0) return null;

  const sessionId = value.slice(0, separator);
  const providedSignature = value.slice(separator + 1);
  const expectedSignature = signSessionId(sessionId);

  const provided = Buffer.from(providedSignature);
  const expected = Buffer.from(expectedSignature);
  if (provided.length !== expected.length) return null;
  if (!crypto.timingSafeEqual(provided, expected)) return null;

  return sessionId;
}

/**
 * Read the session ID from a request's cookie header
 * @param {Object} req - Express request
 * @returns {string|null}
 */
function getSessionIdFromRequest(req) {
  const value = parseCookies(req.headers.cookie)[COOKIE_NAME];
  return value ? verifyCookieValue(value) : null;
}

/**
 * Build the Set-Cookie value for a session
 * @param {Object} req - Express request (used for Secure detection)
 * @param {string} sessionId
 * @returns {string}
 */
function buildSessionCookie(req, sessionId) {
  const forwardedProto = String(req.headers['x-forwarded-proto'] || '').split(',')[0].trim();
  const secure = req.secure || forwardedProto === 'https';

  const attributes = [
    `${COOKIE_NAME}=${encodeURIComponent(`${sessionId}.${signSessionId(sessionId)}`)}`,
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    `Max-Age=${config.multisession.sessionTtlSeconds}`
  ];
  if (secure) attributes.push('Secure');

  return attributes.join('; ');
}

/**
 * Attach the session cookie to a response
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @param {string} sessionId
 */
function setSessionCookie(req, res, sessionId) {
  res.append('Set-Cookie', buildSessionCookie(req, sessionId));
}

/**
 * Expire the session cookie
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
function clearSessionCookie(req, res) {
  res.append('Set-Cookie', [
    `${COOKIE_NAME}=`,
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    'Max-Age=0'
  ].join('; '));
}

module.exports = {
  COOKIE_NAME,
  parseCookies,
  signSessionId,
  verifyCookieValue,
  getSessionIdFromRequest,
  setSessionCookie,
  clearSessionCookie
};
