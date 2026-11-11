/**
 * Candidate-facing hostname of the exam jumphost.
 *
 * The jumphost itself is per session (or one container in single-environment
 * mode), but its visible name follows the certification so CKA candidates see
 * `cka9999`, CKAD candidates see `ckad9999`, and so on. Every session network
 * also aliases the other names so old lab content keeps working.
 */

const HOSTNAME_BY_CATEGORY = {
  CKA: 'cka9999',
  CKAD: 'ckad9999',
  CKS: 'cks9999',
  KCNA: 'kcna9999',
  KCSA: 'kcsa9999',
  PLAYGROUND: 'playground9999',
  OTHER: 'other9999'
};

const DEFAULT_MACHINE_HOSTNAME = 'ckad9999';

/**
 * @param {string} [category] - Lab category (e.g. "CKA", "CKAD")
 * @returns {string} hostname such as "cka9999"
 */
function machineHostname(category) {
  const key = String(category || '').trim().toUpperCase();
  return HOSTNAME_BY_CATEGORY[key] || DEFAULT_MACHINE_HOSTNAME;
}

module.exports = {
  machineHostname,
  machineHostnames: Object.values(HOSTNAME_BY_CATEGORY),
  DEFAULT_MACHINE_HOSTNAME
};
