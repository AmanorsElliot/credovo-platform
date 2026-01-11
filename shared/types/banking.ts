// Open Banking and Financial Data Types

export interface BankAccount {
  accountId: string;
  accountName: string;
  accountType: 'checking' | 'savings' | 'credit' | 'loan' | 'investment' | 'other';
  accountNumber?: string; // Masked for security
  routingNumber?: string;
  institutionName: string;
  institutionId: string;
  balance?: {
    available?: number;
    current?: number;
    limit?: number;
    currency: string;
  };
  metadata?: Record<string, any>;
}

export interface Transaction {
  transactionId: string;
  accountId: string;
  amount: number;
  currency: string;
  date: string; // ISO date string
  name: string;
  merchantName?: string;
  category?: string[];
  categoryId?: string;
  type: 'debit' | 'credit';
  pending: boolean;
  metadata?: Record<string, any>;
}

export interface IncomeVerification {
  applicationId: string;
  userId: string;
  status: 'pending' | 'verified' | 'failed' | 'requires_review';
  provider: string;
  incomeData?: {
    annualIncome?: number;
    monthlyIncome?: number;
    currency: string;
    incomeSources: IncomeSource[];
    verificationDate: Date;
    confidence?: number; // 0-100
  };
  bankAccounts?: BankAccount[];
  transactions?: Transaction[];
  timestamp: Date;
}

export interface IncomeSource {
  type: 'salary' | 'self_employed' | 'investment' | 'pension' | 'benefits' | 'other';
  amount: number;
  frequency: 'weekly' | 'biweekly' | 'monthly' | 'quarterly' | 'annually';
  description?: string;
}

export interface BankLinkRequest {
  applicationId: string;
  userId: string;
  institutionId?: string; // Pre-selected institution
  products: PlaidProduct[]; // What data to access
  redirectUri?: string;
  webhook?: string;
}

export interface BankLinkResponse {
  linkToken: string;
  expiration: Date;
  requestId: string;
}

export interface BankLinkExchangeRequest {
  applicationId: string;
  userId: string;
  publicToken: string;
}

export interface BankLinkExchangeResponse {
  accessToken: string;
  itemId: string;
  requestId: string;
}

export interface AccountBalanceRequest {
  applicationId: string;
  userId: string;
  accessToken: string;
  accountIds?: string[]; // Optional: specific accounts
}

export interface AccountBalanceResponse {
  accounts: BankAccount[];
  requestId: string;
}

export interface TransactionRequest {
  applicationId: string;
  userId: string;
  accessToken: string;
  accountId?: string;
  startDate: string; // ISO date
  endDate: string; // ISO date
  count?: number; // Max transactions to return
}

export interface TransactionResponse {
  transactions: Transaction[];
  totalTransactions: number;
  requestId: string;
}

export type PlaidProduct = 
  | 'transactions'
  | 'auth'
  | 'identity'
  | 'income'
  | 'assets'
  | 'investments'
  | 'liabilities';

export interface PlaidWebhook {
  webhook_type: string;
  webhook_code: string;
  item_id: string;
  error?: {
    error_type: string;
    error_code: string;
    error_message: string;
  };
  new_transactions?: number;
  removed_transactions?: string[];
  [key: string]: any;
}
