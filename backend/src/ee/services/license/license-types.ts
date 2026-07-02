import { TOrgPermission } from "@app/lib/types";

export enum InstanceType {
  OnPrem = "self-hosted",
  EnterpriseOnPrem = "enterprise-self-hosted",
  EnterpriseOnPremOffline = "enterprise-self-hosted-offline",
  // Self-hosted instance whose license is resolved from License Server v2 (new "infisical_lk_" key).
  EnterpriseOnPremV2 = "enterprise-self-hosted-v2",
  Cloud = "cloud"
}

export type TOfflineLicenseContents = {
  license: TOfflineLicense;
  signature: string;
};

export type TOfflineLicense = {
  issuedTo: string;
  licenseId: string;
  customerId: string | null;
  issuedAt: string;
  expiresAt: string | null;
  terminatesAt: string | null;
  features: TFeatureSet;
};

export type TPlanBillingInfo = {
  currentPeriodStart: number;
  currentPeriodEnd: number;
  interval: "month" | "year";
  intervalCount: number;
  amount: number;
  quantity: number;
};

export type TFeatureSet = {
  _id: null;
  slug: string | null;
  tier: number;
  workspaceLimit: number | null;
  workspacesUsed: number;
  dynamicSecret: boolean;
  memberLimit: number | null;
  membersUsed: number;
  identityLimit: number | null;
  identitiesUsed: number;
  enforceIdentityLimit?: boolean;
  subOrganization: boolean;
  environmentLimit: number | null;
  environmentsUsed: number;
  secretVersioning: boolean;
  pitRecovery: boolean;
  ipAllowlisting: boolean;
  rbac: boolean;
  customRateLimits: boolean;
  customAlerts: boolean;
  auditLogs: boolean;
  auditLogsRetentionDays: number;
  auditLogStreams: boolean;
  auditLogStreamLimit: number;
  githubOrgSync: boolean;
  samlSSO: boolean;
  enforceGoogleSSO: boolean;
  hsm: boolean;
  oidcSSO: boolean;
  secretAccessInsights: boolean;
  scim: boolean;
  ldap: boolean;
  groups: boolean;
  status: null;
  trial_end: null;
  has_used_trial: boolean;
  secretApproval: boolean;
  secretRotation: boolean;
  caCrl: boolean;
  instanceUserManagement: boolean;
  externalKms: boolean;
  rateLimits: {
    readLimit: number;
    writeLimit: number;
    secretsLimit: number;
  };
  pkiEst: boolean;
  pkiAcme: boolean;
  pkiScep: boolean;
  pkiPqc: boolean;
  kmsPqc: boolean;
  enforceMfa: boolean;
  projectTemplates: boolean;
  kmip: boolean;
  gateway: boolean;
  gatewayPool: boolean;
  sshHostGroups: boolean;
  secretScanning: boolean;
  enterpriseSecretSyncs: boolean;
  enterpriseCertificateSyncs: boolean;
  enterpriseAppConnections: boolean;
  machineIdentityAuthTemplates: boolean;
  pkiLegacyTemplates: boolean;
  fips: boolean;
  eventSubscriptions: boolean;
  secretShareExternalBranding: boolean;
  honeyTokens: boolean;
  honeyTokenLimit: number;
};

export type TOrgPlansTableDTO = {
  billingCycle: string;
} & TOrgPermission;

export type TOrgPlanDTO = {
  projectId?: string;
  refreshCache?: boolean;
  rootOrgId: string;
} & TOrgPermission;

export type TStartOrgTrialDTO = {
  success_url: string;
} & TOrgPermission;

export type TCreateOrgPortalSession = TOrgPermission;

export type TGetOrgBillInfoDTO = TOrgPermission;

export type TOrgPlanTableDTO = TOrgPermission;

export type TOrgBillingDetailsDTO = TOrgPermission;

export type TUpdateOrgBillingDetailsDTO = TOrgPermission & {
  name?: string;
  email?: string;
};

export type TOrgPmtMethodsDTO = TOrgPermission;

export type TAddOrgPmtMethodDTO = TOrgPermission & { success_url: string; cancel_url: string };

export type TDelOrgPmtMethodDTO = TOrgPermission & { pmtMethodId: string };

export type TGetOrgTaxIdDTO = TOrgPermission;

export type TAddOrgTaxIdDTO = TOrgPermission & { type: string; value: string };

export type TDelOrgTaxIdDTO = TOrgPermission & { taxId: string };

export type TOrgInvoiceDTO = TOrgPermission;

export type TOrgLicensesDTO = TOrgPermission;

export enum LicenseType {
  Offline = "offline",
  Online = "online",
  // New self-hosted key (prefix "infisical_lk_") that resolves entitlements from License Server v2.
  OnlineV2 = "online-v2"
}

export type TLicenseKeyConfig =
  | {
      isValid: false;
    }
  | {
      isValid: true;
      licenseKey: string;
      type: LicenseType;
    };
