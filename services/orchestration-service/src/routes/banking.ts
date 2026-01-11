import { Router, Request, Response } from 'express';
import axios from 'axios';
import { createLogger } from '@credovo/shared-utils/logger';
import { validateRequest, validateParams } from '@credovo/shared-types/validation-middleware';
import { 
  ApplicationIdParamSchema, 
  BankLinkRequestSchema, 
  BankLinkExchangeRequestSchema,
  AccountBalanceRequestSchema,
  TransactionRequestSchema
} from '@credovo/shared-types/validation';

const logger = createLogger('orchestration-banking');
export const BankingRouter = Router();

const OPEN_BANKING_SERVICE_URL = process.env.OPEN_BANKING_SERVICE_URL || 'http://open-banking-service:8080';

// Helper function to get Cloud Run identity token
async function getIdentityToken(audience: string): Promise<string | null> {
  try {
    const metadataServerTokenUrl = 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity';
    const response = await axios.get(metadataServerTokenUrl, {
      params: { audience },
      headers: { 'Metadata-Flavor': 'Google' },
      timeout: 5000
    });
    return typeof response.data === 'string' ? response.data.trim() : response.data;
  } catch (error: any) {
    logger.warn('Failed to get identity token', { error: error.message });
    return null;
  }
}

// Helper function to create service token
function createServiceToken(): string {
  const serviceSecret = process.env.SERVICE_JWT_SECRET;
  if (!serviceSecret) {
    throw new Error('SERVICE_JWT_SECRET not configured');
  }
  const jwt = require('jsonwebtoken');
  return jwt.sign(
    { service: 'orchestration-service', iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 300 },
    serviceSecret,
    { algorithm: 'HS256' }
  );
}

/**
 * Create Plaid Link Token
 * POST /api/v1/applications/:applicationId/banking/link-token
 */
BankingRouter.post('/:applicationId/banking/link-token',
  validateParams(ApplicationIdParamSchema),
  validateRequest({ body: BankLinkRequestSchema.omit({ applicationId: true, userId: true }) }),
  async (req: Request, res: Response) => {
    try {
      const applicationId = req.params.applicationId;
      const userId = req.userId;

      if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const identityToken = await getIdentityToken(OPEN_BANKING_SERVICE_URL);
      const serviceToken = createServiceToken();

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'X-Service-Token': serviceToken,
      };
      if (identityToken) {
        headers['Authorization'] = `Bearer ${identityToken}`;
      }

      const validatedBody = {
        ...req.body,
        applicationId,
        userId
      };

      const response = await axios.post(
        `${OPEN_BANKING_SERVICE_URL}/api/v1/banking/link-token`,
        validatedBody,
        { headers }
      );

      res.json(response.data);
    } catch (error: any) {
      logger.error('Failed to create link token', error);
      res.status(error.response?.status || 500).json({
        error: 'Failed to create link token',
        message: error.message
      });
    }
  }
);

/**
 * Exchange Public Token
 * POST /api/v1/applications/:applicationId/banking/exchange-token
 */
BankingRouter.post('/:applicationId/banking/exchange-token',
  validateParams(ApplicationIdParamSchema),
  validateRequest({ body: BankLinkExchangeRequestSchema.omit({ applicationId: true, userId: true }) }),
  async (req: Request, res: Response) => {
    try {
      const applicationId = req.params.applicationId;
      const userId = req.userId;

      if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const identityToken = await getIdentityToken(OPEN_BANKING_SERVICE_URL);
      const serviceToken = createServiceToken();

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'X-Service-Token': serviceToken,
      };
      if (identityToken) {
        headers['Authorization'] = `Bearer ${identityToken}`;
      }

      const validatedBody = {
        ...req.body,
        applicationId,
        userId
      };

      const response = await axios.post(
        `${OPEN_BANKING_SERVICE_URL}/api/v1/banking/exchange-token`,
        validatedBody,
        { headers }
      );

      res.json(response.data);
    } catch (error: any) {
      logger.error('Failed to exchange token', error);
      res.status(error.response?.status || 500).json({
        error: 'Failed to exchange token',
        message: error.message
      });
    }
  }
);

/**
 * Get Account Balances
 * POST /api/v1/applications/:applicationId/banking/accounts/balance
 */
BankingRouter.post('/:applicationId/banking/accounts/balance',
  validateParams(ApplicationIdParamSchema),
  validateRequest({ body: AccountBalanceRequestSchema.omit({ applicationId: true, userId: true }) }),
  async (req: Request, res: Response) => {
    try {
      const applicationId = req.params.applicationId;
      const userId = req.userId;

      if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const identityToken = await getIdentityToken(OPEN_BANKING_SERVICE_URL);
      const serviceToken = createServiceToken();

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'X-Service-Token': serviceToken,
      };
      if (identityToken) {
        headers['Authorization'] = `Bearer ${identityToken}`;
      }

      const validatedBody = {
        ...req.body,
        applicationId,
        userId
      };

      const response = await axios.post(
        `${OPEN_BANKING_SERVICE_URL}/api/v1/banking/accounts/balance`,
        validatedBody,
        { headers }
      );

      res.json(response.data);
    } catch (error: any) {
      logger.error('Failed to get account balances', error);
      res.status(error.response?.status || 500).json({
        error: 'Failed to get account balances',
        message: error.message
      });
    }
  }
);

/**
 * Get Transactions
 * POST /api/v1/applications/:applicationId/banking/transactions
 */
BankingRouter.post('/:applicationId/banking/transactions',
  validateParams(ApplicationIdParamSchema),
  validateRequest({ body: TransactionRequestSchema.omit({ applicationId: true, userId: true }) }),
  async (req: Request, res: Response) => {
    try {
      const applicationId = req.params.applicationId;
      const userId = req.userId;

      if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const identityToken = await getIdentityToken(OPEN_BANKING_SERVICE_URL);
      const serviceToken = createServiceToken();

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'X-Service-Token': serviceToken,
      };
      if (identityToken) {
        headers['Authorization'] = `Bearer ${identityToken}`;
      }

      const validatedBody = {
        ...req.body,
        applicationId,
        userId
      };

      const response = await axios.post(
        `${OPEN_BANKING_SERVICE_URL}/api/v1/banking/transactions`,
        validatedBody,
        { headers }
      );

      res.json(response.data);
    } catch (error: any) {
      logger.error('Failed to get transactions', error);
      res.status(error.response?.status || 500).json({
        error: 'Failed to get transactions',
        message: error.message
      });
    }
  }
);

/**
 * Create Income Verification
 * POST /api/v1/applications/:applicationId/banking/income/verify
 */
BankingRouter.post('/:applicationId/banking/income/verify',
  validateParams(ApplicationIdParamSchema),
  async (req: Request, res: Response) => {
    try {
      const applicationId = req.params.applicationId;
      const userId = req.userId;

      if (!userId) {
        return res.status(401).json({ error: 'Unauthorized' });
      }

      const identityToken = await getIdentityToken(OPEN_BANKING_SERVICE_URL);
      const serviceToken = createServiceToken();

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'X-Service-Token': serviceToken,
      };
      if (identityToken) {
        headers['Authorization'] = `Bearer ${identityToken}`;
      }

      const validatedBody = {
        ...req.body,
        applicationId,
        userId
      };

      const response = await axios.post(
        `${OPEN_BANKING_SERVICE_URL}/api/v1/banking/income/verify`,
        validatedBody,
        { headers }
      );

      res.json(response.data);
    } catch (error: any) {
      logger.error('Failed to create income verification', error);
      res.status(error.response?.status || 500).json({
        error: 'Failed to create income verification',
        message: error.message
      });
    }
  }
);
