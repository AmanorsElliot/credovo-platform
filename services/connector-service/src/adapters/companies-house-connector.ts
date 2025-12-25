import { BaseConnector, ConnectorFeatures } from './base-connector';
import { ConnectorRequest } from '@credovo/shared-types';

export class CompaniesHouseConnector extends BaseConnector {
  protected providerName = 'companies-house';
  protected baseUrl = 'https://api.company-information.service.gov.uk';

  getFeatures(): ConnectorFeatures {
    return {
      kyb: true
    };
  }

  async call(request: ConnectorRequest): Promise<any> {
    // Companies House uses Basic Auth with API key
    const apiKey = await this.getApiKey();
    
    if (!apiKey) {
      throw new Error('Companies House API key not configured');
    }

    // Companies House uses Basic Auth: base64(api_key:)
    const authHeader = Buffer.from(`${apiKey}:`).toString('base64');

    return this.makeRequest(
      request.method,
      request.endpoint,
      {
        ...request.headers,
        'Authorization': `Basic ${authHeader}`
      },
      request.body
    );
  }
}

