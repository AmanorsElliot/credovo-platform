import { Router, Request, Response } from 'express';
import { createLogger } from '@credovo/shared-utils/logger';
import { PlaidService } from '../services/plaid-service';
import {
  BankLinkRequest,
  BankLinkExchangeRequest,
  AccountBalanceRequest,
  TransactionRequest,
} from '@credovo/shared-types';
import { validateBody } from '@credovo/shared-types/validation-middleware';
import {
  BankLinkRequestSchema,
  BankLinkExchangeRequestSchema,
  AccountBalanceRequestSchema,
  TransactionRequestSchema
} from '@credovo/shared-types/validation';

const logger = createLogger('banking-routes');
export const BankingRouter = Router();

const plaidService = new PlaidService();

/**
 * Create Plaid Link Token
 * POST /api/v1/banking/link-token
 */
BankingRouter.post('/link-token',
  validateBody(BankLinkRequestSchema.partial({ applicationId: true })),
  async (req: Request, res: Response) => {
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

    const response = await plaidService.createLinkToken(request);
    res.json(response);
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
BankingRouter.post('/exchange-token',
  validateBody(BankLinkExchangeRequestSchema),
  async (req: Request, res: Response) => {
    try {
      const request: BankLinkExchangeRequest = {
        applicationId: req.body.applicationId,
        userId: req.userId || req.body.userId,
        publicToken: req.body.publicToken,
      };

    const response = await plaidService.exchangePublicToken(request);
    res.json(response);
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
BankingRouter.post('/accounts/balance',
  validateBody(AccountBalanceRequestSchema),
  async (req: Request, res: Response) => {
    try {
      const request: AccountBalanceRequest = {
        applicationId: req.body.applicationId,
        userId: req.userId || req.body.userId,
        accessToken: req.body.accessToken,
        accountIds: req.body.accountIds,
      };

    const response = await plaidService.getAccountBalances(request);
    res.json(response);
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
BankingRouter.post('/transactions',
  validateBody(TransactionRequestSchema),
  async (req: Request, res: Response) => {
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

    const response = await plaidService.getTransactions(request);
    res.json(response);
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
    const applicationId = req.body.applicationId;
    const userId = req.userId || req.body.userId;
    const accessToken = req.body.accessToken;

    if (!accessToken) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'accessToken is required'
      });
    }

    const response = await plaidService.createIncomeVerification(applicationId, userId, accessToken);
    res.json(response);
  } catch (error: any) {
    logger.error('Failed to create income verification', error);
    res.status(error.response?.status || 500).json({
      error: 'Failed to create income verification',
      message: error.message
    });
  }
});
