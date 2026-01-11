// Shared types across all services

// Export banking types
export * from './banking';

// Export validation schemas
export * from './validation';
export * from './validation-middleware';

export interface Application {
  id: string;
  userId: string;
  status: ApplicationStatus;
  createdAt: Date;
  updatedAt: Date;
  data: Record<string, any>;
}

export enum ApplicationStatus {
  PENDING = 'pending',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  REJECTED = 'rejected',
  FAILED = 'failed'
}

export interface KYCRequest {
  applicationId: string;
  userId: string;
  type: 'individual' | 'company';
  data: {
    firstName?: string;
    lastName?: string;
    dateOfBirth?: string;
    email?: string;
    country?: string;
    address?: Address;
    companyNumber?: string;
    companyName?: string;
  };
}

export interface Address {
  line1: string;
  line2?: string;
  city: string;
  postcode: string;
  country: string;
}

export interface KYCResponse {
  applicationId: string;
  status: 'pending' | 'approved' | 'rejected' | 'requires_review';
  provider: string;
  result?: {
    score?: number;
    checks?: CheckResult[];
    metadata?: Record<string, any>;
    aml?: any; // AML screening results
  };
  timestamp: Date;
}

export interface CheckResult {
  type: string;
  status: 'pass' | 'fail' | 'warning';
  message?: string;
}

export interface KYBRequest {
  applicationId: string;
  companyNumber: string;
  companyName?: string;
  country?: string; // ISO country code (e.g., 'GB', 'US', 'DE') for international support
}

export interface KYBResponse {
  applicationId: string;
  companyNumber: string;
  status: 'verified' | 'pending' | 'not_found' | 'error';
  data?: {
    companyName: string;
    status: string;
    incorporationDate?: string;
    address?: Address;
    officers?: any[];
    verificationLevel?: string;
    checks?: any[];
    metadata?: any;
    aml?: any; // AML screening results
  };
  timestamp: Date;
}

export interface ConnectorRequest {
  provider: string;
  endpoint: string;
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  headers?: Record<string, string>;
  body?: any;
  retry?: boolean;
}

export interface ConnectorResponse<T = any> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
  // Shufti Pro specific fields (optional, as they may not be present for all providers)
  event?: string;
  status?: string;
  verification_result?: any;
  reference?: string;
  risk_assessment?: any;
  // Plaid specific fields (optional, as they may not be present for all providers)
  link_token?: string;
  expiration?: string;
  access_token?: string;
  item_id?: string;
  accounts?: any[];
  transactions?: any[];
  total_transactions?: number;
  request_id?: string;
  metadata?: {
    provider: string;
    latency: number;
    retries?: number;
  };
}

export interface ApiError {
  code: string;
  message: string;
  statusCode: number;
  details?: any;
}

