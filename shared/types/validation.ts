import { z } from 'zod';

// Address validation schema
export const AddressSchema = z.object({
  line1: z.string().min(1, 'Address line 1 is required').max(200, 'Address line 1 is too long'),
  line2: z.string().max(200, 'Address line 2 is too long').optional(),
  city: z.string().min(1, 'City is required').max(100, 'City name is too long'),
  postcode: z.string().min(1, 'Postcode is required').max(20, 'Postcode is too long'),
  country: z.string().length(2, 'Country must be a 2-letter ISO code').regex(/^[A-Z]{2}$/, 'Country must be uppercase ISO code')
});

// KYC Request validation schema (base schema without refine for omit operations)
export const KYCRequestBaseSchema = z.object({
  applicationId: z.string().min(1, 'Application ID is required').max(100, 'Application ID is too long'),
  userId: z.string().min(1, 'User ID is required').max(100, 'User ID is too long'),
  type: z.enum(['individual', 'company']),
  data: z.object({
    firstName: z.string().min(1, 'First name is required').max(100, 'First name is too long').optional(),
    lastName: z.string().min(1, 'Last name is required').max(100, 'Last name is too long').optional(),
    dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date of birth must be in YYYY-MM-DD format').optional(),
    email: z.string().email('Invalid email format').max(255, 'Email is too long').optional(),
    country: z.string().length(2, 'Country must be a 2-letter ISO code').regex(/^[A-Z]{2}$/, 'Country must be uppercase ISO code').optional(),
    address: AddressSchema.optional(),
    companyNumber: z.string().min(1, 'Company number is required').max(50, 'Company number is too long').optional(),
    companyName: z.string().min(1, 'Company name is required').max(200, 'Company name is too long').optional()
  })
});

// KYC Request validation schema (with refine)
export const KYCRequestSchema = KYCRequestBaseSchema.refine(
  (data: any) => {
    // If type is individual, require firstName and lastName
    if (data.type === 'individual') {
      return data.data.firstName && data.data.lastName;
    }
    // If type is company, require companyNumber or companyName
    if (data.type === 'company') {
      return data.data.companyNumber || data.data.companyName;
    }
    return true;
  },
  {
    message: 'Required fields missing for the selected type'
  }
);

// KYB Request validation schema
export const KYBRequestSchema = z.object({
  applicationId: z.string().min(1, 'Application ID is required').max(100, 'Application ID is too long'),
  companyNumber: z.string().min(1, 'Company number is required').max(50, 'Company number is too long'),
  companyName: z.string().min(1, 'Company name is required').max(200, 'Company name is too long').optional(),
  country: z.string().length(2, 'Country must be a 2-letter ISO code').regex(/^[A-Z]{2}$/, 'Country must be uppercase ISO code').optional(),
  email: z.string().email('Invalid email format').max(255, 'Email is too long').optional()
});

// Company Search validation schema
export const CompanySearchQuerySchema = z.object({
  query: z.string().min(2, 'Query must be at least 2 characters').max(200, 'Query is too long'),
  limit: z.coerce.number().int('Limit must be an integer').min(1, 'Limit must be at least 1').max(50, 'Limit cannot exceed 50').default(10).optional()
});

// Banking Link Token Request validation schema
export const BankLinkRequestSchema = z.object({
  applicationId: z.string().min(1, 'Application ID is required').max(100, 'Application ID is too long'),
  userId: z.string().min(1, 'User ID is required').max(100, 'User ID is too long'),
  institutionId: z.string().max(100, 'Institution ID is too long').optional(),
  products: z.array(z.enum(['transactions', 'auth', 'identity', 'income', 'assets', 'investments', 'liabilities'])).min(1, 'At least one product is required').default(['transactions', 'auth']).optional(),
  redirectUri: z.string().url('Invalid redirect URI').max(500, 'Redirect URI is too long').optional(),
  webhook: z.string().url('Invalid webhook URL').max(500, 'Webhook URL is too long').optional()
});

// Banking Exchange Token Request validation schema
export const BankLinkExchangeRequestSchema = z.object({
  applicationId: z.string().min(1, 'Application ID is required').max(100, 'Application ID is too long'),
  userId: z.string().min(1, 'User ID is required').max(100, 'User ID is too long'),
  publicToken: z.string().min(1, 'Public token is required').max(500, 'Public token is too long')
});

// Account Balance Request validation schema
export const AccountBalanceRequestSchema = z.object({
  applicationId: z.string().min(1, 'Application ID is required').max(100, 'Application ID is too long'),
  userId: z.string().min(1, 'User ID is required').max(100, 'User ID is too long'),
  accessToken: z.string().min(1, 'Access token is required').max(500, 'Access token is too long'),
  accountIds: z.array(z.string().min(1).max(100)).max(100, 'Too many account IDs').optional()
});

// Transaction Request validation schema (base schema without refine for omit operations)
export const TransactionRequestBaseSchema = z.object({
  applicationId: z.string().min(1, 'Application ID is required').max(100, 'Application ID is too long'),
  userId: z.string().min(1, 'User ID is required').max(100, 'User ID is too long'),
  accessToken: z.string().min(1, 'Access token is required').max(500, 'Access token is too long'),
  accountId: z.string().min(1, 'Account ID is required').max(100, 'Account ID is too long').optional(),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Start date must be in YYYY-MM-DD format'),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'End date must be in YYYY-MM-DD format'),
  count: z.coerce.number().int('Count must be an integer').min(1, 'Count must be at least 1').max(500, 'Count cannot exceed 500').default(100).optional()
});

// Transaction Request validation schema (with refine)
export const TransactionRequestSchema = TransactionRequestBaseSchema.refine(
  (data: any) => {
    const start = new Date(data.startDate);
    const end = new Date(data.endDate);
    return start <= end;
  },
  {
    message: 'Start date must be before or equal to end date',
    path: ['endDate']
  }
).refine(
  (data: any) => {
    const start = new Date(data.startDate);
    const end = new Date(data.endDate);
    const daysDiff = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
    return daysDiff <= 730; // Max 2 years
  },
  {
    message: 'Date range cannot exceed 2 years',
    path: ['endDate']
  }
);

// Auth Token Exchange Request validation schema
export const AuthTokenRequestSchema = z.object({
  userId: z.string().min(1, 'User ID is required').max(100, 'User ID is too long'),
  email: z.string().email('Invalid email format').max(255, 'Email is too long').optional(),
  name: z.string().max(200, 'Name is too long').optional()
});

// Connector Request validation schema
export const ConnectorRequestSchema = z.object({
  provider: z.string().min(1, 'Provider is required').max(50, 'Provider name is too long'),
  endpoint: z.string().min(1, 'Endpoint is required').max(500, 'Endpoint is too long'),
  method: z.enum(['GET', 'POST', 'PUT', 'DELETE']),
  headers: z.record(z.string(), z.string()).optional(),
  body: z.any().optional(),
  retry: z.boolean().optional()
});

// Application ID parameter validation
export const ApplicationIdParamSchema = z.object({
  applicationId: z.string().min(1, 'Application ID is required').max(100, 'Application ID is too long')
});
