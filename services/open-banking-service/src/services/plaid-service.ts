import { DataLakeService } from './data-lake-service';
import { ConnectorClient } from './connector-client';
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

const logger = createLogger('plaid-service');

export class PlaidService {
  private dataLake: DataLakeService;
  private connector: ConnectorClient;

  constructor() {
    this.dataLake = new DataLakeService();
    this.connector = new ConnectorClient();
  }

  /**
   * Create Plaid Link Token
   */
  async createLinkToken(request: BankLinkRequest): Promise<BankLinkResponse> {
    logger.info('Creating Plaid link token', {
      applicationId: request.applicationId,
      userId: request.userId,
    });

    try {
      // Store request in data lake
      await this.dataLake.storePlaidRequest('link-token', request.applicationId, request);

      // Build webhook URL
      const orchestrationServiceUrl = process.env.ORCHESTRATION_SERVICE_URL || 'https://orchestration-service-saz24fo3sa-ew.a.run.app';
      const webhookUrl = request.webhook || `${orchestrationServiceUrl}/api/v1/webhooks/plaid`;

      // Call connector service to create link token
      const connectorRequest = {
        provider: 'plaid',
        endpoint: '/link/token/create',
        method: 'POST' as const,
        body: {
          clientName: 'Credovo',
          products: request.products || ['transactions', 'auth'],
          countryCodes: ['US', 'GB'],
          language: 'en',
          userId: request.userId,
          applicationId: request.applicationId,
          webhook: webhookUrl,
          redirectUri: request.redirectUri,
          institutionId: request.institutionId,
        },
        retry: true,
      };

      // Store raw API request
      await this.dataLake.storeRawAPIRequest('plaid', request.applicationId, {
        ...connectorRequest,
        timestamp: new Date(),
      });

      const connectorResponse = await this.connector.call(connectorRequest);

      // Store raw API response
      await this.dataLake.storeRawAPIResponse('plaid', request.applicationId, {
        ...connectorResponse,
        timestamp: new Date(),
      });

      if (!connectorResponse.success || !connectorResponse.link_token) {
        throw new Error(connectorResponse.error?.message || 'Failed to create link token');
      }

      const linkResponse: BankLinkResponse = {
        linkToken: connectorResponse.link_token,
        expiration: new Date(connectorResponse.expiration),
        requestId: connectorResponse.request_id,
      };

      // Store response
      await this.dataLake.storePlaidResponse('link-token', request.applicationId, linkResponse);

      return linkResponse;
    } catch (error: any) {
      logger.error('Failed to create link token', error);
      throw error;
    }
  }

  /**
   * Exchange Public Token for Access Token
   */
  async exchangePublicToken(request: BankLinkExchangeRequest): Promise<BankLinkExchangeResponse> {
    logger.info('Exchanging Plaid public token', {
      applicationId: request.applicationId,
      userId: request.userId,
    });

    try {
      // Store request
      await this.dataLake.storePlaidRequest('exchange-token', request.applicationId, request);

      // Call connector service
      const connectorRequest = {
        provider: 'plaid',
        endpoint: '/item/public_token/exchange',
        method: 'POST' as const,
        body: {
          publicToken: request.publicToken,
        },
        retry: true,
      };

      await this.dataLake.storeRawAPIRequest('plaid', request.applicationId, {
        ...connectorRequest,
        timestamp: new Date(),
      });

      const connectorResponse = await this.connector.call(connectorRequest);

      await this.dataLake.storeRawAPIResponse('plaid', request.applicationId, {
        ...connectorResponse,
        timestamp: new Date(),
      });

      if (!connectorResponse.success || !connectorResponse.access_token) {
        throw new Error(connectorResponse.error?.message || 'Failed to exchange token');
      }

      const exchangeResponse: BankLinkExchangeResponse = {
        accessToken: connectorResponse.access_token,
        itemId: connectorResponse.item_id,
        requestId: connectorResponse.request_id,
      };

      // Store response
      await this.dataLake.storePlaidResponse('exchange-token', request.applicationId, exchangeResponse);

      return exchangeResponse;
    } catch (error: any) {
      logger.error('Failed to exchange public token', error);
      throw error;
    }
  }

  /**
   * Get Account Balances
   */
  async getAccountBalances(request: AccountBalanceRequest): Promise<AccountBalanceResponse> {
    logger.info('Getting account balances', {
      applicationId: request.applicationId,
      userId: request.userId,
    });

    try {
      // Call connector service
      const connectorRequest = {
        provider: 'plaid',
        endpoint: '/accounts/balance/get',
        method: 'POST' as const,
        body: {
          accessToken: request.accessToken,
          accountIds: request.accountIds,
        },
        retry: true,
      };

      await this.dataLake.storeRawAPIRequest('plaid', request.applicationId, {
        ...connectorRequest,
        timestamp: new Date(),
      });

      const connectorResponse = await this.connector.call(connectorRequest);

      await this.dataLake.storeRawAPIResponse('plaid', request.applicationId, {
        ...connectorResponse,
        timestamp: new Date(),
      });

      if (!connectorResponse.success || !connectorResponse.accounts) {
        throw new Error(connectorResponse.error?.message || 'Failed to get account balances');
      }

      const balanceResponse: AccountBalanceResponse = {
        accounts: connectorResponse.accounts,
        requestId: connectorResponse.request_id,
      };

      return balanceResponse;
    } catch (error: any) {
      logger.error('Failed to get account balances', error);
      throw error;
    }
  }

  /**
   * Get Transactions
   */
  async getTransactions(request: TransactionRequest): Promise<TransactionResponse> {
    logger.info('Getting transactions', {
      applicationId: request.applicationId,
      userId: request.userId,
      startDate: request.startDate,
      endDate: request.endDate,
    });

    try {
      // Call connector service
      const connectorRequest = {
        provider: 'plaid',
        endpoint: '/transactions/get',
        method: 'POST' as const,
        body: {
          accessToken: request.accessToken,
          accountIds: request.accountId ? [request.accountId] : undefined,
          startDate: request.startDate,
          endDate: request.endDate,
          count: request.count || 100,
        },
        retry: true,
      };

      await this.dataLake.storeRawAPIRequest('plaid', request.applicationId, {
        ...connectorRequest,
        timestamp: new Date(),
      });

      const connectorResponse = await this.connector.call(connectorRequest);

      await this.dataLake.storeRawAPIResponse('plaid', request.applicationId, {
        ...connectorResponse,
        timestamp: new Date(),
      });

      if (!connectorResponse.success || !connectorResponse.transactions) {
        throw new Error(connectorResponse.error?.message || 'Failed to get transactions');
      }

      const transactionResponse: TransactionResponse = {
        transactions: connectorResponse.transactions,
        totalTransactions: connectorResponse.total_transactions,
        requestId: connectorResponse.request_id,
      };

      return transactionResponse;
    } catch (error: any) {
      logger.error('Failed to get transactions', error);
      throw error;
    }
  }

  /**
   * Create Income Verification
   */
  async createIncomeVerification(
    applicationId: string,
    userId: string,
    accessToken: string
  ): Promise<IncomeVerification> {
    logger.info('Creating income verification', {
      applicationId,
      userId,
    });

    try {
      // Build webhook URL
      const orchestrationServiceUrl = process.env.ORCHESTRATION_SERVICE_URL || 'https://orchestration-service-saz24fo3sa-ew.a.run.app';
      const webhookUrl = `${orchestrationServiceUrl}/api/v1/webhooks/plaid`;

      // Call connector service
      const connectorRequest = {
        provider: 'plaid',
        endpoint: '/income/verification/create',
        method: 'POST' as const,
        body: {
          accessToken,
          webhook: webhookUrl,
        },
        retry: true,
      };

      await this.dataLake.storeRawAPIRequest('plaid', applicationId, {
        ...connectorRequest,
        timestamp: new Date(),
      });

      const connectorResponse = await this.connector.call(connectorRequest);

      await this.dataLake.storeRawAPIResponse('plaid', applicationId, {
        ...connectorResponse,
        timestamp: new Date(),
      });

      if (!connectorResponse.success) {
        throw new Error(connectorResponse.error?.message || 'Failed to create income verification');
      }

      const incomeVerification: IncomeVerification = {
        applicationId,
        userId,
        status: 'pending',
        provider: 'plaid',
        timestamp: new Date(),
      };

      // Store response
      await this.dataLake.storePlaidResponse('income-verification', applicationId, incomeVerification);

      return incomeVerification;
    } catch (error: any) {
      logger.error('Failed to create income verification', error);
      throw error;
    }
  }
}
