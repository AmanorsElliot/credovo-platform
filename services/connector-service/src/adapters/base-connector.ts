import { ConnectorRequest } from '@credovo/shared-types';

export interface ConnectorFeatures {
  kyc?: boolean;
  kyb?: boolean;
  creditCheck?: boolean;
  avm?: boolean;
  [key: string]: boolean | undefined;
}

export abstract class BaseConnector {
  protected abstract providerName: string;
  protected abstract baseUrl: string;

  abstract call(request: ConnectorRequest): Promise<any>;
  
  abstract getFeatures(): ConnectorFeatures;

  protected async getApiKey(): Promise<string> {
    // In production, fetch from Secret Manager
    const secretName = `${this.providerName}-api-key`;
    return process.env[secretName.toUpperCase().replace(/-/g, '_')] || '';
  }

  protected async makeRequest(
    method: 'GET' | 'POST' | 'PUT' | 'DELETE',
    endpoint: string,
    headers: Record<string, string> = {},
    body?: any
  ): Promise<any> {
    const apiKey = await this.getApiKey();
    const url = `${this.baseUrl}${endpoint}`;

    const requestHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
      ...headers
    };

    // Add API key to headers (provider-specific)
    if (apiKey) {
      requestHeaders['Authorization'] = `Bearer ${apiKey}`;
    }

    const axios = (await import('axios')).default;
    const response = await axios({
      method,
      url,
      headers: requestHeaders,
      data: body,
      validateStatus: (status) => status < 500
    });

    if (response.status >= 400) {
      throw new Error(`API request failed: ${response.status} ${JSON.stringify(response.data)}`);
    }

    return response.data;
  }
}

