import axios from 'axios';
import jwt from 'jsonwebtoken';
import { createLogger } from '@credovo/shared-utils/logger';
import { ConnectorRequest, ConnectorResponse } from '@credovo/shared-types';

const logger = createLogger('connector-client');

export class ConnectorClient {
  private connectorServiceUrl: string;

  constructor() {
    this.connectorServiceUrl = process.env.CONNECTOR_SERVICE_URL || 'http://connector-service:8080';
  }

  async call(request: ConnectorRequest): Promise<ConnectorResponse<any>> {
    try {
      // Get Cloud Run identity token for IAM authentication
      const identityToken = await this.getIdentityToken(this.connectorServiceUrl);
      
      // Create application-level service token
      const serviceToken = this.createServiceToken();

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'X-Service-Token': serviceToken,
      };

      // Add IAM token if available
      if (identityToken) {
        headers['Authorization'] = `Bearer ${identityToken}`;
      }

      logger.debug('Calling connector service', {
        provider: request.provider,
        endpoint: request.endpoint,
        method: request.method,
      });

      const response = await axios.post(
        `${this.connectorServiceUrl}/api/v1/connector/call`,
        request,
        { headers, timeout: 30000 }
      );

      return response.data;
    } catch (error: any) {
      logger.error('Connector service call failed', {
        error: error.message,
        provider: request.provider,
        endpoint: request.endpoint,
      });
      throw error;
    }
  }

  private async getIdentityToken(audience: string): Promise<string | null> {
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

  private createServiceToken(): string {
    const serviceSecret = process.env.SERVICE_JWT_SECRET;
    if (!serviceSecret) {
      throw new Error('SERVICE_JWT_SECRET not configured');
    }
    return jwt.sign(
      { service: 'open-banking-service', iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 300 },
      serviceSecret,
      { algorithm: 'HS256' }
    );
  }
}
