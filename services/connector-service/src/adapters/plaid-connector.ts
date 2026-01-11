import { BaseConnector, ConnectorFeatures } from './base-connector';
import { ConnectorRequest } from '@credovo/shared-types';
import axios from 'axios';

/**
 * Plaid Connector for Open Banking Integration
 * 
 * Plaid provides:
 * - Account verification and authentication
 * - Transaction history
 * - Income verification
 * - Identity verification
 * - Asset verification
 * 
 * Documentation: https://plaid.com/docs/
 */
export class PlaidConnector extends BaseConnector {
  protected providerName = 'plaid';
  protected baseUrl = process.env.PLAID_ENV === 'production' 
    ? 'https://production.plaid.com'
    : 'https://sandbox.plaid.com'; // Default to sandbox

  getFeatures(): ConnectorFeatures {
    return {
      openBanking: true,
      incomeVerification: true,
      accountVerification: true,
      transactionHistory: true,
      identityVerification: true,
    };
  }

  async call(request: ConnectorRequest): Promise<any> {
    const clientId = await this.getClientId();
    const secret = await this.getSecretKey();

    if (!clientId || !secret) {
      throw new Error('Plaid credentials not configured (need client_id and secret)');
    }

    // Determine which Plaid endpoint to call based on request
    if (request.endpoint?.includes('/link/token/create')) {
      return this.handleLinkTokenCreate(request, clientId, secret);
    } else if (request.endpoint?.includes('/item/public_token/exchange')) {
      return this.handlePublicTokenExchange(request, clientId, secret);
    } else if (request.endpoint?.includes('/accounts/balance/get')) {
      return this.handleAccountBalance(request, clientId, secret);
    } else if (request.endpoint?.includes('/transactions/get') || request.endpoint?.includes('/transactions/sync')) {
      return this.handleTransactions(request, clientId, secret);
    } else if (request.endpoint?.includes('/income/verification/create')) {
      return this.handleIncomeVerification(request, clientId, secret);
    } else {
      // Generic Plaid API call
      return this.handleGenericRequest(request, clientId, secret);
    }
  }

  private async getClientId(): Promise<string> {
    const secretName = `${this.providerName}-client-id`;
    return process.env[secretName.toUpperCase().replace(/-/g, '_')] || '';
  }

  private async getSecretKey(): Promise<string> {
    const secretName = `${this.providerName}-secret-key`;
    return process.env[secretName.toUpperCase().replace(/-/g, '_')] || '';
  }

  /**
   * Create Link Token for Plaid Link initialization
   */
  private async handleLinkTokenCreate(request: ConnectorRequest, clientId: string, secret: string): Promise<any> {
    const payload = {
      client_id: clientId,
      secret: secret,
      client_name: request.body?.clientName || 'Credovo',
      products: request.body?.products || ['transactions', 'auth'],
      country_codes: request.body?.countryCodes || ['US', 'GB'],
      language: request.body?.language || 'en',
      user: {
        client_user_id: request.body?.userId || request.body?.applicationId,
      },
      webhook: request.body?.webhook,
      redirect_uri: request.body?.redirectUri,
    };

    const response = await this.makeRequest(
      'POST',
      '/link/token/create',
      {
        'Content-Type': 'application/json',
      },
      payload
    );

    return {
      success: true,
      link_token: response.link_token,
      expiration: response.expiration,
      request_id: response.request_id,
    };
  }

  /**
   * Exchange public token for access token
   */
  private async handlePublicTokenExchange(request: ConnectorRequest, clientId: string, secret: string): Promise<any> {
    const payload = {
      client_id: clientId,
      secret: secret,
      public_token: request.body?.publicToken,
    };

    const response = await this.makeRequest(
      'POST',
      '/item/public_token/exchange',
      {
        'Content-Type': 'application/json',
      },
      payload
    );

    return {
      success: true,
      access_token: response.access_token,
      item_id: response.item_id,
      request_id: response.request_id,
    };
  }

  /**
   * Get account balances
   */
  private async handleAccountBalance(request: ConnectorRequest, clientId: string, secret: string): Promise<any> {
    const payload = {
      client_id: clientId,
      secret: secret,
      access_token: request.body?.accessToken,
      options: {
        account_ids: request.body?.accountIds,
      },
    };

    const response = await this.makeRequest(
      'POST',
      '/accounts/balance/get',
      {
        'Content-Type': 'application/json',
      },
      payload
    );

    return {
      success: true,
      accounts: response.accounts,
      request_id: response.request_id,
    };
  }

  /**
   * Get transactions
   */
  private async handleTransactions(request: ConnectorRequest, clientId: string, secret: string): Promise<any> {
    const payload = {
      client_id: clientId,
      secret: secret,
      access_token: request.body?.accessToken,
      start_date: request.body?.startDate,
      end_date: request.body?.endDate,
      account_ids: request.body?.accountIds,
      count: request.body?.count || 100,
      offset: request.body?.offset || 0,
      options: {
        include_personal_finance_category: true,
      },
    };

    const response = await this.makeRequest(
      'POST',
      '/transactions/get',
      {
        'Content-Type': 'application/json',
      },
      payload
    );

    return {
      success: true,
      transactions: response.transactions,
      total_transactions: response.total_transactions,
      request_id: response.request_id,
    };
  }

  /**
   * Create income verification
   */
  private async handleIncomeVerification(request: ConnectorRequest, clientId: string, secret: string): Promise<any> {
    const payload = {
      client_id: clientId,
      secret: secret,
      access_token: request.body?.accessToken,
      webhook: request.body?.webhook,
    };

    const response = await this.makeRequest(
      'POST',
      '/income/verification/create',
      {
        'Content-Type': 'application/json',
      },
      payload
    );

    return {
      success: true,
      income_verification_id: response.income_verification_id,
      request_id: response.request_id,
    };
  }

  /**
   * Generic Plaid API request handler
   */
  private async handleGenericRequest(request: ConnectorRequest, clientId: string, secret: string): Promise<any> {
    const payload = {
      client_id: clientId,
      secret: secret,
      ...request.body,
    };

    const endpoint = request.endpoint || '/';
    const method = request.method || 'POST';

    return this.makeRequest(
      method as 'GET' | 'POST' | 'PUT' | 'DELETE',
      endpoint,
      {
        'Content-Type': 'application/json',
      },
      payload
    );
  }

  /**
   * Override makeRequest to use Plaid's authentication format
   */
  protected async makeRequest(
    method: 'GET' | 'POST' | 'PUT' | 'DELETE',
    endpoint: string,
    headers: Record<string, string> = {},
    body?: any
  ): Promise<any> {
    const url = `${this.baseUrl}${endpoint}`;

    const requestHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
      ...headers
    };

    try {
      const response = await axios({
        method,
        url,
        headers: requestHeaders,
        data: body,
        validateStatus: (status) => status < 500,
      });

      if (response.status >= 400) {
        const error = response.data.error || {};
        throw new Error(`Plaid API error: ${error.error_type || 'UNKNOWN'} - ${error.error_message || JSON.stringify(response.data)}`);
      }

      return response.data;
    } catch (error: any) {
      if (error.response) {
        const plaidError = error.response.data.error || {};
        throw new Error(`Plaid API error: ${plaidError.error_type || 'UNKNOWN'} - ${plaidError.error_message || error.message}`);
      }
      throw error;
    }
  }
}
