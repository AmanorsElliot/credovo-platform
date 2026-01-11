import { Router, Request, Response } from 'express';
import axios from 'axios';
import { createLogger } from '@credovo/shared-utils/logger';
import {
  BankLinkRequest,
  BankLinkResponse,
  BankLinkExchangeRequest,
  BankLinkExchangeResponse,
  AccountBalanceRequest,
  AccountBalanceResponse,
  TransactionRequest,
  TransactionResponse,
  IncomeVerification,
} from '@credovo/shared-types';

const logger = createLogger('banking-routes');
export const BankingRouter = Router();

const CONNECTOR_SERVICE_URL = process.env.CONNECTOR_SERVICE_URL || 'http://connector-service:8080';

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
    { service: 'open-banking-service', iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 300 },
    serviceSecret,
    { algorithm: 'HS256' }
  );
}

/**
 * Create Plaid Link Token
 * POST /api/v1/banking/link-token
 */
BankingRouter.post('/link-token', async (req: Request, res: Response) => {
  try {
    const request: BankLinkRequest = {
      applicationId: req.body.applicationId || `app-${Date.now()}`,
      userId: req.userId || req.body.userId,
      institutionId: req.body.institutionId,
      products: req.body.products || ['transactions', 'auth'],
      redirectUri: req.body.redirectUri,
      webhook: req.body.webhook,
    };

    if (!request.userId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'userId is required'
      });
    }

    const identityToken = await getIdentityToken(CONNECTOR_SERVICE_URL);
    const serviceToken = createServiceToken();

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Service-Token': serviceToken,
    };
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`;
    }

    // Build webhook URL if not provided
    const orchestrationUrl = process.env.ORCHESTRATION_SERVICE_URL || 'https://orchestration-service-saz24fo3sa-ew.a.run.app';
    const webhookUrl = request.webhook || `${orchestrationUrl}/api/v1/webhooks/plaid`;

    const connectorRequest = {
      provider: 'plaid',
      endpoint: '/link/token/create',
      method: 'POST' as const,
      body: {
        clientName: 'Credovo',
        products: request.products,
        countryCodes: ['US', 'GB'], // Support US and UK initially
        language: 'en',
        userId: request.userId,
        applicationId: request.applicationId,
        webhook: webhookUrl,
        redirectUri: request.redirectUri,
      },
    };

    const response = await axios.post(
      `${CONNECTOR_SERVICE_URL}/api/v1/connector/call`,
      connectorRequest,
      { headers }
    );

    if (response.data.success) {
      const linkResponse: BankLinkResponse = {
        linkToken: response.data.link_token,
        expiration: new Date(response.data.expiration),
        requestId: response.data.request_id,
      };
      res.json(linkResponse);
    } else {
      throw new Error(response.data.error?.message || 'Failed to create link token');
    }
  } catch (error: any) {
    logger.error('Failed to create link token', error);
    res.status(error.response?.status || 500).json({
      error: 'Failed to create link token',
      message: error.message
    });
  }
});

/**
 * Exchange Public Token for Access Token
 * POST /api/v1/banking/exchange-token
 */
BankingRouter.post('/exchange-token', async (req: Request, res: Response) => {
  try {
    const request: BankLinkExchangeRequest = {
      applicationId: req.body.applicationId,
      userId: req.userId || req.body.userId,
      publicToken: req.body.publicToken,
    };

    if (!request.publicToken || !request.userId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'publicToken and userId are required'
      });
    }

    const identityToken = await getIdentityToken(CONNECTOR_SERVICE_URL);
    const serviceToken = createServiceToken();

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Service-Token': serviceToken,
    };
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`;
    }

    const connectorRequest = {
      provider: 'plaid',
      endpoint: '/item/public_token/exchange',
      method: 'POST' as const,
      body: {
        publicToken: request.publicToken,
      },
    };

    const response = await axios.post(
      `${CONNECTOR_SERVICE_URL}/api/v1/connector/call`,
      connectorRequest,
      { headers }
    );

    if (response.data.success) {
      const exchangeResponse: BankLinkExchangeResponse = {
        accessToken: response.data.access_token,
        itemId: response.data.item_id,
        requestId: response.data.request_id,
      };
      res.json(exchangeResponse);
    } else {
      throw new Error(response.data.error?.message || 'Failed to exchange token');
    }
  } catch (error: any) {
    logger.error('Failed to exchange token', error);
    res.status(error.response?.status || 500).json({
      error: 'Failed to exchange token',
      message: error.message
    });
  }
});

/**
 * Get Account Balances
 * POST /api/v1/banking/accounts/balance
 */
BankingRouter.post('/accounts/balance', async (req: Request, res: Response) => {
  try {
    const request: AccountBalanceRequest = {
      applicationId: req.body.applicationId,
      userId: req.userId || req.body.userId,
      accessToken: req.body.accessToken,
      accountIds: req.body.accountIds,
    };

    if (!request.accessToken) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'accessToken is required'
      });
    }

    const identityToken = await getIdentityToken(CONNECTOR_SERVICE_URL);
    const serviceToken = createServiceToken();

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Service-Token': serviceToken,
    };
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`;
    }

    const connectorRequest = {
      provider: 'plaid',
      endpoint: '/accounts/balance/get',
      method: 'POST' as const,
      body: {
        accessToken: request.accessToken,
        accountIds: request.accountIds,
      },
    };

    const response = await axios.post(
      `${CONNECTOR_SERVICE_URL}/api/v1/connector/call`,
      connectorRequest,
      { headers }
    );

    if (response.data.success) {
      const balanceResponse: AccountBalanceResponse = {
        accounts: response.data.accounts,
        requestId: response.data.request_id,
      };
      res.json(balanceResponse);
    } else {
      throw new Error(response.data.error?.message || 'Failed to get account balances');
    }
  } catch (error: any) {
    logger.error('Failed to get account balances', error);
    res.status(error.response?.status || 500).json({
      error: 'Failed to get account balances',
      message: error.message
    });
  }
});

/**
 * Get Transactions
 * POST /api/v1/banking/transactions
 */
BankingRouter.post('/transactions', async (req: Request, res: Response) => {
  try {
    const request: TransactionRequest = {
      applicationId: req.body.applicationId,
      userId: req.userId || req.body.userId,
      accessToken: req.body.accessToken,
      accountId: req.body.accountId,
      startDate: req.body.startDate,
      endDate: req.body.endDate,
      count: req.body.count || 100,
    };

    if (!request.accessToken || !request.startDate || !request.endDate) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'accessToken, startDate, and endDate are required'
      });
    }

    const identityToken = await getIdentityToken(CONNECTOR_SERVICE_URL);
    const serviceToken = createServiceToken();

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Service-Token': serviceToken,
    };
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`;
    }

    const connectorRequest = {
      provider: 'plaid',
      endpoint: '/transactions/get',
      method: 'POST' as const,
      body: {
        accessToken: request.accessToken,
        accountIds: request.accountId ? [request.accountId] : undefined,
        startDate: request.startDate,
        endDate: request.endDate,
        count: request.count,
      },
    };

    const response = await axios.post(
      `${CONNECTOR_SERVICE_URL}/api/v1/connector/call`,
      connectorRequest,
      { headers }
    );

    if (response.data.success) {
      const transactionResponse: TransactionResponse = {
        transactions: response.data.transactions,
        totalTransactions: response.data.total_transactions,
        requestId: response.data.request_id,
      };
      res.json(transactionResponse);
    } else {
      throw new Error(response.data.error?.message || 'Failed to get transactions');
    }
  } catch (error: any) {
    logger.error('Failed to get transactions', error);
    res.status(error.response?.status || 500).json({
      error: 'Failed to get transactions',
      message: error.message
    });
  }
});

/**
 * Create Income Verification
 * POST /api/v1/banking/income/verify
 */
BankingRouter.post('/income/verify', async (req: Request, res: Response) => {
  try {
    const request = {
      applicationId: req.body.applicationId,
      userId: req.userId || req.body.userId,
      accessToken: req.body.accessToken,
    };

    if (!request.accessToken) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'accessToken is required'
      });
    }

    const identityToken = await getIdentityToken(CONNECTOR_SERVICE_URL);
    const serviceToken = createServiceToken();

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Service-Token': serviceToken,
    };
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`;
    }

    const orchestrationUrl = process.env.ORCHESTRATION_SERVICE_URL || 'https://orchestration-service-saz24fo3sa-ew.a.run.app';
    const webhookUrl = `${orchestrationUrl}/api/v1/webhooks/plaid`;

    const connectorRequest = {
      provider: 'plaid',
      endpoint: '/income/verification/create',
      method: 'POST' as const,
      body: {
        accessToken: request.accessToken,
        webhook: webhookUrl,
      },
    };

    const response = await axios.post(
      `${CONNECTOR_SERVICE_URL}/api/v1/connector/call`,
      connectorRequest,
      { headers }
    );

    if (response.data.success) {
      const incomeVerification: IncomeVerification = {
        applicationId: request.applicationId,
        userId: request.userId,
        status: 'pending',
        provider: 'plaid',
        timestamp: new Date(),
      };
      res.json(incomeVerification);
    } else {
      throw new Error(response.data.error?.message || 'Failed to create income verification');
    }
  } catch (error: any) {
    logger.error('Failed to create income verification', error);
    res.status(error.response?.status || 500).json({
      error: 'Failed to create income verification',
      message: error.message
    });
  }
});
