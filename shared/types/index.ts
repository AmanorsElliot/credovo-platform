// Shared types across all services

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
}

export interface KYBResponse {
  applicationId: string;
  companyNumber: string;
  status: 'verified' | 'not_found' | 'error';
  data?: {
    companyName: string;
    status: string;
    incorporationDate?: string;
    address?: Address;
    officers?: any[];
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

