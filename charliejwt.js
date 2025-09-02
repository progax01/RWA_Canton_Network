/*
 * This script generates two JSON Web Tokens (JWTs) for use with the Canton
 * JSON API:
 *
 *   1. A user‑based token for the Canton user "NewCharlie".  This
 *      token references an existing user record via the `sub` claim and
 *      expects that the user has already been created and granted
 *      appropriate actAs/readAs rights via the user management API.
 *
 *   2. A multi‑party claim token named "charlie_bank_token".  This
 *      token embeds both NewCharlie and NewBank in the `actAs` and
 *      `readAs` claims, allowing operations that involve both parties
 *      (for example, transfers that are controlled by Charlie but also
 *      need to access Bank data).
 *
 * Before running this script, ensure that:
 *   - You have allocated the party for NewCharlie and have the full
 *     party identifier (including the hash suffix).  Assign this to
 *     CHARLIE_PARTY below.
 *   - You know the full party identifier for your bank (NewBank).  Assign
 *     this to BANK_PARTY below.
 *   - You have created the Canton users "NewCharlie" and
 *     "charlie_bank_token" via the JSON API’s user/create endpoint and
 *     granted them the necessary rights.
 *   - The private RSA key used to sign tokens is available at
 *     config/jwt/jwt-sign.key, or set the JWT_PRIVATE_KEY environment
 *     variable to point to your key.
 *
 * Run the script with Node:
 *
 *     node generate_charlie_tokens.js
 *
 * It will print the two tokens to stdout.  You can redirect the
 * output to files as needed.
 */

const fs = require('fs');
const jwt = require('jsonwebtoken');

// ---------------------------------------------------------------------------
// Configuration: Replace these values with your actual party identifiers.
// You can also override them at runtime by setting the environment
// variables CHARLIE_PARTY and BANK_PARTY.
const CHARLIE_PARTY = process.env.CHARLIE_PARTY || 'NewCharlie::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d';
const BANK_PARTY    = process.env.BANK_PARTY    || 'NewBank::1220b845dcf0d9cf52ce1e7457a744a6f3de7eff4a9ee95261b69405d1e0de8a768d';

// JWT signing configuration.  You can override these defaults by
// exporting the corresponding environment variables.
const privateKeyPath = process.env.JWT_PRIVATE_KEY || 'config/jwt/jwt-sign.key';
const DEFAULT_SCOPE  = process.env.JWT_SCOPE      || 'daml_ledger_api';
const DEFAULT_AUD    = process.env.JWT_AUDIENCE   || 'https://daml.com/jwt/aud/participant/participant1';
const DEFAULT_ISS    = process.env.JWT_ISSUER     || 'canton-jwt-issuer';
const APPLICATION_ID = process.env.JWT_APPLICATION_ID || 'rwa-json-api';
const ONE_YEAR_IN_SECONDS = 365 * 24 * 60 * 60;

// Load the private key for signing.  Exit with an error if it cannot be found.
if (!fs.existsSync(privateKeyPath)) {
  console.error(`Error: private key file not found at ${privateKeyPath}`);
  process.exit(1);
}
const privateKey = fs.readFileSync(privateKeyPath);

// ---------------------------------------------------------------------------
// Helper functions to generate JWT payloads

function generateUserTokenPayload(userId) {
  const now = Math.floor(Date.now() / 1000);
  return {
    scope: DEFAULT_SCOPE,
    aud: DEFAULT_AUD,
    sub: userId,
    iss: DEFAULT_ISS,
    exp: now + ONE_YEAR_IN_SECONDS,
    iat: now,
    applicationId: APPLICATION_ID,
  };
}

function generateMultiPartyPayload(tokenName, parties) {
  const now = Math.floor(Date.now() / 1000);
  return {
    scope: DEFAULT_SCOPE,
    aud: DEFAULT_AUD,
    sub: tokenName,
    iss: DEFAULT_ISS,
    exp: now + ONE_YEAR_IN_SECONDS,
    iat: now,
    actAs: parties,
    readAs: parties,
    applicationId: APPLICATION_ID,
  };
}

function signToken(payload) {
  return jwt.sign(payload, privateKey, { algorithm: 'RS256' });
}

// ---------------------------------------------------------------------------
// Generate and print tokens

function main() {
  // Single‑user token for NewCharlie (userId is "NewCharlie").  The user
  // must already exist and have rights granted via user management.
  const charlieUserPayload = generateUserTokenPayload('NewCharlie');
  const charlieUserToken   = signToken(charlieUserPayload);
  console.log('NewCharlie user token:');
  console.log(charlieUserToken);
  console.log('');

  // Multi‑party claim token for Charlie and the Bank.  The subject (sub)
  // "charlie_bank_token" is an arbitrary descriptive name.
  const charlieBankPayload = generateMultiPartyPayload('charlie_bank_token', [CHARLIE_PARTY, BANK_PARTY]);
  const charlieBankToken   = signToken(charlieBankPayload);
  console.log('charlie_bank_token (multi‑party) token:');
  console.log(charlieBankToken);
  console.log('');
}

main();