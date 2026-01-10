import { BaseConnector, ConnectorFeatures } from './base-connector';
import { ConnectorRequest } from '@credovo/shared-types';

export class SumSubConnector extends BaseConnector {
  protected providerName = 'sumsub';
  protected baseUrl = 'https://api.sumsub.com';

  getFeatures(): ConnectorFeatures {
    return {
      kyc: true,
      kyb: true
    };
  }

  async call(request: ConnectorRequest): Promise<any> {
    // SumSub specific implementation
    if (request.endpoint.startsWith('/resources/applicants')) {
      return this.handleApplicantRequest(request);
    }

    // Handle company verification endpoints
    if (request.endpoint.startsWith('/resources/applicants') && request.body?.type === 'company') {
      return this.handleCompanyVerification(request);
    }

    return this.makeRequest(
      request.method,
      request.endpoint,
      request.headers,
      request.body
    );
  }

  private async handleApplicantRequest(request: ConnectorRequest): Promise<any> {
    // SumSub applicant creation/verification logic (for individuals)
    if (request.method === 'POST') {
      // Check if it's a company verification
      if (request.body?.type === 'company') {
        return this.handleCompanyVerification(request);
      }
      return this.createApplicant(request.body);
    } else if (request.method === 'GET') {
      return this.getApplicantStatus(request.endpoint);
    }

    return this.makeRequest(
      request.method,
      request.endpoint,
      request.headers,
      request.body
    );
  }

  private async handleCompanyVerification(request: ConnectorRequest): Promise<any> {
    // SumSub KYB (company verification) logic
    // SumSub uses the same applicants endpoint for both KYC and KYB
    // The difference is in the body.type field ('company' for KYB)
    const apiKey = await this.getApiKey();
    const appToken = process.env.SUMSUB_APP_TOKEN || '';

    // Prepare company verification request
    const companyData = {
      externalUserId: request.body.externalUserId,
      type: 'company', // Indicates this is a company verification
      info: {
        companyName: request.body.info?.companyName,
        companyNumber: request.body.info?.companyNumber,
        country: request.body.info?.country || 'GB',
        ...request.body.info
      }
    };

    const response = await this.makeRequest(
      'POST',
      '/resources/applicants',
      {
        'X-App-Token': appToken,
        'X-App-Access-Sig': this.generateSignature(companyData, apiKey),
        'Content-Type': 'application/json'
      },
      companyData
    );

    return response;
  }

  private async createApplicant(data: any): Promise<any> {
    const apiKey = await this.getApiKey();
    const appToken = process.env.SUMSUB_APP_TOKEN || '';

    const response = await this.makeRequest(
      'POST',
      '/resources/applicants',
      {
        'X-App-Token': appToken,
        'X-App-Access-Sig': this.generateSignature(data, apiKey)
      },
      data
    );

    return response;
  }

  private async getApplicantStatus(endpoint: string): Promise<any> {
    return this.makeRequest('GET', endpoint);
  }

  private generateSignature(data: any, secret: string): string {
    // SumSub signature generation logic
    const crypto = require('crypto');
    const payload = JSON.stringify(data);
    return crypto.createHmac('sha256', secret).update(payload).digest('hex');
  }
}

