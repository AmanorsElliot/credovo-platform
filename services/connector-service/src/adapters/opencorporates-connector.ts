import { BaseConnector, ConnectorFeatures } from './base-connector';
import { ConnectorRequest } from '@credovo/shared-types';
import axios from 'axios';

/**
 * OpenCorporates Connector for Company Search
 * 
 * OpenCorporates provides:
 * - Global company database (200+ million companies)
 * - Company search with autocomplete
 * - Company details and filings
 * - Free tier available
 * - No HubSpot account required
 * 
 * Documentation: https://opencorporates.com/api_accounts/new
 */
export class OpenCorporatesConnector extends BaseConnector {
  protected providerName = 'opencorporates';
  protected baseUrl = 'https://api.opencorporates.com';

  getFeatures(): ConnectorFeatures {
    return {
      companySearch: true,
      companyEnrichment: true,
      autocomplete: true,
    };
  }

  async call(request: ConnectorRequest): Promise<any> {
    const apiToken = await this.getApiToken();

    // OpenCorporates allows requests without API token (rate limited)
    // API token increases rate limits
    const authParam = apiToken ? { api_token: apiToken } : {};

    if (request.endpoint?.includes('/companies/search')) {
      return this.handleCompanySearch(request, authParam);
    } else if (request.endpoint?.includes('/companies/')) {
      return this.handleCompanyLookup(request, authParam);
    } else {
      return this.handleGenericRequest(request, authParam);
    }
  }

  private async getApiToken(): Promise<string> {
    const secretName = `${this.providerName}-api-token`;
    return process.env[secretName.toUpperCase().replace(/-/g, '_')] || '';
  }

  /**
   * Company Search
   * GET /v0.4.8/companies/search?q=company+name
   */
  private async handleCompanySearch(request: ConnectorRequest, authParams: Record<string, string>): Promise<any> {
    const query = request.body?.query || request.body?.q || request.body?.name || '';
    
    if (!query || query.length < 2) {
      throw new Error('Company name or query is required (minimum 2 characters)');
    }

    try {
      const response = await axios.get(
        `${this.baseUrl}/v0.4.8/companies/search`,
        {
          params: {
            q: query,
            per_page: request.body?.limit || request.body?.per_page || 10,
            ...authParams,
          },
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Credovo-Platform/1.0',
          },
          timeout: 10000,
        }
      );

      const companies = response.data?.results?.companies || [];
      
      return {
        success: true,
        companies: companies.map((company: any) => ({
          name: company.company?.name,
          companyNumber: company.company?.company_number,
          jurisdiction: company.company?.jurisdiction_code,
          jurisdictionCode: company.company?.jurisdiction_code,
          companyType: company.company?.company_type,
          status: company.company?.current_status,
          incorporationDate: company.company?.incorporation_date,
          dissolutionDate: company.company?.dissolution_date,
          address: company.company?.registered_address_in_full,
          url: company.company?.opencorporates_url,
        })),
        count: companies.length,
        totalResults: response.data?.results?.total_count || companies.length,
      };
    } catch (error: any) {
      if (error.response?.status === 404) {
        return {
          success: true,
          companies: [],
          count: 0,
          totalResults: 0,
        };
      }
      throw error;
    }
  }

  /**
   * Company Lookup by Number and Jurisdiction
   * GET /v0.4.8/companies/{jurisdiction}/{company_number}
   */
  private async handleCompanyLookup(request: ConnectorRequest, authParams: Record<string, string>): Promise<any> {
    const jurisdiction = request.body?.jurisdiction || request.body?.jurisdiction_code || 'gb';
    const companyNumber = request.body?.company_number || request.body?.companyNumber;

    if (!companyNumber) {
      throw new Error('Company number is required for company lookup');
    }

    try {
      const response = await axios.get(
        `${this.baseUrl}/v0.4.8/companies/${jurisdiction}/${companyNumber}`,
        {
          params: authParams,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Credovo-Platform/1.0',
          },
          timeout: 10000,
        }
      );

      const company = response.data?.results?.company;

      return {
        success: true,
        company: {
          name: company?.name,
          companyNumber: company?.company_number,
          jurisdiction: company?.jurisdiction_code,
          companyType: company?.company_type,
          status: company?.current_status,
          incorporationDate: company?.incorporation_date,
          dissolutionDate: company?.dissolution_date,
          address: company?.registered_address_in_full,
          url: company?.opencorporates_url,
          officers: company?.officers,
          filings: company?.filings,
        },
      };
    } catch (error: any) {
      if (error.response?.status === 404) {
        return {
          success: false,
          error: {
            code: 'COMPANY_NOT_FOUND',
            message: 'Company not found',
          },
        };
      }
      throw error;
    }
  }

  /**
   * Generic OpenCorporates API request handler
   */
  private async handleGenericRequest(request: ConnectorRequest, authParams: Record<string, string>): Promise<any> {
    const endpoint = request.endpoint || '/';
    const method = request.method || 'GET';

    try {
      const response = await axios({
        method,
        url: `${this.baseUrl}${endpoint}`,
        params: {
          ...authParams,
          ...request.body?.params,
        },
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Credovo-Platform/1.0',
          ...request.headers,
        },
        data: request.body,
        timeout: 10000,
      });

      return {
        success: true,
        data: response.data,
      };
    } catch (error: any) {
      if (error.response) {
        const ocError = error.response.data || {};
        throw new Error(`OpenCorporates API error: ${ocError.error || error.message}`);
      }
      throw error;
    }
  }
}
