/**
 * Session lookup for the web application.
 *
 * The browser talks to the webapp (nginx -> webapp). The webapp needs to know
 * which desktop/terminal containers belong to the caller's session, so it asks
 * the facilitator with the caller's signed cookie and caches the answer
 * briefly. When multisession is disabled the facilitator answers 404 and the
 * webapp falls back to the single-environment configuration.
 */

const http = require('http');

const FACILITATOR_URL = process.env.FACILITATOR_URL || 'http://facilitator:3000';
const CACHE_TTL_MS = 10 * 1000;
const FAILURE_TTL_MS = 2000;
const LOOKUP_TIMEOUT_MS = 3000;

const cache = new Map();

// The webapp image runs Node 16, so use http.request instead of global fetch.
function httpGetJson(urlString, headers, timeoutMs) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlString);
    const request = http.request({
      hostname: url.hostname,
      port: url.port || 80,
      path: `${url.pathname}${url.search}`,
      method: 'GET',
      headers,
      timeout: timeoutMs
    }, (response) => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => { body += chunk; });
      response.on('end', () => resolve({ status: response.statusCode, body }));
    });

    request.on('timeout', () => request.destroy(new Error('session lookup timed out')));
    request.on('error', reject);
    request.end();
  });
}

function cacheKey(cookieHeader) {
  return cookieHeader || '';
}

function getCached(key) {
  const entry = cache.get(key);
  if (!entry) return null;
  if (entry.expiresAt <= Date.now()) {
    cache.delete(key);
    return null;
  }
  return entry.value;
}

function setCached(key, value, ttl = CACHE_TTL_MS) {
  cache.set(key, { value, expiresAt: Date.now() + ttl });
  // Keep the map from growing without bound when many browsers come and go.
  if (cache.size > 500) {
    const now = Date.now();
    for (const [k, entry] of cache) {
      if (entry.expiresAt <= now) cache.delete(k);
    }
  }
}

/**
 * Fetch the caller's session environment from the facilitator.
 *
 * @param {string} [cookieHeader] - The browser's Cookie header
 * @returns {Promise<Object|null>} env descriptor, or null when the facilitator
 *   runs in single-environment mode / the session is unknown
 */
async function fetchSessionEnv(cookieHeader) {
  if (!cookieHeader) return null;

  const url = `${FACILITATOR_URL}/api/v1/sessions/me`;
  try {
    const response = await httpGetJson(url, { cookie: cookieHeader }, LOOKUP_TIMEOUT_MS);

    if (response.status === 404) {
      // Multisession disabled: caller must use the static configuration.
      return null;
    }

    if (response.status !== 200) {
      throw new Error(`session lookup failed with ${response.status}`);
    }

    const body = JSON.parse(response.body);
    return body && body.env ? body : null;
  } catch (error) {
    console.error(`Session lookup failed: ${error.message}`);
    return null;
  }
}

/**
 * Resolve the session for a request or socket handshake.
 *
 * @param {Object} req - Express request or socket.io handshake-like object
 * @returns {Promise<Object|null>} `{ sessionId, examId, env }` or null
 */
async function resolveSession(req) {
  const headers = (req && req.headers) || {};
  const cookieHeader = typeof headers.cookie === 'string' ? headers.cookie : '';
  const key = cacheKey(cookieHeader);

  const cached = getCached(key);
  if (cached !== null) return cached;

  const value = cookieHeader ? await fetchSessionEnv(cookieHeader) : null;

  // Cache misses (single-env mode, no cookie) briefly: a fresh session appears
  // as soon as the candidate starts a lab.
  setCached(key, value, value ? CACHE_TTL_MS : FAILURE_TTL_MS);
  return value;
}

/**
 * Build proxy/SSH targets for a request, falling back to the static
 * single-environment configuration when there is no session.
 *
 * @param {Object} req
 * @param {Object} fallback - { vncHost, vncPort, vncPassword, sshHost, sshPort, sshPassword }
 * @returns {Promise<Object>}
 */
async function resolveTargets(req, fallback) {
  const session = await resolveSession(req);
  const env = (session && session.env) || {};

  return {
    sessionId: session ? session.sessionId : null,
    multisession: Boolean(session),
    vncHost: env.remoteDesktopHost || fallback.vncHost,
    vncPort: env.remoteDesktopPort || fallback.vncPort,
    vncPassword: env.vncPassword || fallback.vncPassword,
    sshHost: env.remoteTerminalHost || fallback.sshHost,
    sshPort: env.remoteTerminalPort || fallback.sshPort,
    sshPassword: env.remoteTerminalPassword || fallback.sshPassword
  };
}

module.exports = {
  resolveSession,
  resolveTargets
};
