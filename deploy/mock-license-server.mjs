#!/usr/bin/env node
/**
 * Mock license server for local development.
 *
 * Usage:
 *   node scripts/mock-license-server.mjs
 *
 * Then in your .env:
 *   LICENSE_KEY=MOCK-LICENSE-KEY
 *   LICENSE_SERVER_URL=http://localhost:3001
 */

import { createServer } from "node:http";

const PORT = process.env.MOCK_LICENSE_PORT || 3001;

const ENTERPRISE_PLAN = {
  _id: null,
  slug: "enterprise",
  tier: 4,
  workspaceLimit: null,
  workspacesUsed: 0,
  memberLimit: null,
  membersUsed: 0,
  environmentLimit: null,
  environmentsUsed: 0,
  identityLimit: null,
  identitiesUsed: 0,
  enforceIdentityLimit: false,
  dynamicSecret: true,
  secretVersioning: true,
  pitRecovery: true,
  ipAllowlisting: true,
  rbac: true,
  githubOrgSync: true,
  customRateLimits: true,
  subOrganization: true,
  customAlerts: true,
  secretAccessInsights: true,
  auditLogs: true,
  auditLogsRetentionDays: 365,
  auditLogStreams: true,
  auditLogStreamLimit: 100,
  samlSSO: true,
  enforceGoogleSSO: true,
  hsm: true,
  oidcSSO: true,
  scim: true,
  ldap: true,
  groups: true,
  status: null,
  trial_end: null,
  has_used_trial: true,
  secretApproval: true,
  secretRotation: true,
  caCrl: true,
  instanceUserManagement: true,
  externalKms: true,
  rateLimits: { readLimit: 60, writeLimit: 200, secretsLimit: 40 },
  pkiEst: true,
  pkiAcme: true,
  pkiScep: true,
  pkiPqc: true,
  kmsPqc: true,
  enforceMfa: true,
  projectTemplates: true,
  kmip: true,
  gateway: true,
  gatewayPool: true,
  sshHostGroups: true,
  secretScanning: true,
  enterpriseSecretSyncs: true,
  enterpriseCertificateSyncs: true,
  enterpriseAppConnections: true,
  fips: true,
  eventSubscriptions: true,
  machineIdentityAuthTemplates: true,
  pkiLegacyTemplates: true,
  secretShareExternalBranding: true,
  honeyTokens: true,
  honeyTokenLimit: 1000,
};

const ROUTES = {
  // Healthcheck for Docker
  "GET /health": () => ({ ok: true }),

  // OnPrem login — LICENSE_KEY triggers this path
  "POST /api/auth/v1/license-login": () => ({ token: "mock-token-onprem" }),

  // Cloud login — LICENSE_SERVER_KEY triggers this path (unused here but kept for completeness)
  "POST /api/auth/v1/license-server-login": () => ({ token: "mock-token-cloud" }),

  // OnPrem plan sync (every 10 min cron + init)
  "GET /api/license/v1/plan": () => ({ currentPlan: ENTERPRISE_PLAN }),

  // OnPrem seat update (PATCH on member count change)
  "PATCH /api/license/v1/license": () => ({}),
};

const server = createServer((req, res) => {
  const key = `${req.method} ${req.url.split("?")[0]}`;
  const handler = ROUTES[key];

  res.setHeader("Content-Type", "application/json");

  if (handler) {
    console.log(`[mock-license] ${key}`);
    res.writeHead(200);
    res.end(JSON.stringify(handler()));
  } else {
    console.warn(`[mock-license] UNHANDLED: ${key}`);
    res.writeHead(404);
    res.end(JSON.stringify({ message: `No mock handler for ${key}` }));
  }
});

server.listen(PORT, () => {
  console.log(`[mock-license] Server running at http://localhost:${PORT}`);
  console.log(`[mock-license] Set in your .env:`);
  console.log(`  LICENSE_KEY=MOCK-LICENSE-KEY`);
  console.log(`  LICENSE_SERVER_URL=http://localhost:${PORT}`);
});
