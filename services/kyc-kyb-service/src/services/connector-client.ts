import axios from 'axios';
import jwt from 'jsonwebtoken';
import { ConnectorRequest, ConnectorResponse } from '@credovo/shared-types';
import { createLogger } from '@credovo/shared-utils/logger';

const logger = createLogger('connector-client');

export class ConnectorClient {
  private baseUrl: string;

  constructor() {
    this.baseUrl = process.env.CONNECTOR_SERVICE_URL || 'http://connector-service:8080';
  }

  // Helper function to get Cloud Run identity token for service-to-service calls
  private async getIdentityToken(audience: string): Promise<string | null> {
    try {
      const metadataServerTokenUrl = 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity';
      const response = await axios.get(metadataServerTokenUrl, {
        params: {
          audience: audience
        },
        headers: {
          'Metadata-Flavor': 'Google'
        },
        timeout: 5000
      });
      // The response should be the token as a string
      const token = typeof response.data === 'string' ? response.data.trim() : response.data;
      logger.debug('Successfully retrieved identity token from Metadata Server');
      return token;
    } catch (error: any) {
      logger.warn('Failed to get identity token from Metadata Server', {
        error: error.message,
        code: error.code
      });
      // Return null to indicate we should skip IAM token (services might be public)
      return null;
    }
  }

  // Helper function to create a service-to-service JWT token
  private createServiceToken(): string {
    const serviceSecret = process.env.SERVICE_JWT_SECRET;
    if (!serviceSecret) {
      throw new Error('SERVICE_JWT_SECRET not configured');
    }
    
    return jwt.sign(
      {
        service: 'kyc-kyb-service',
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 300 // 5 minutes
      },
      serviceSecret,
      { algorithm: 'HS256' }
    );
  }

  async call(request: ConnectorRequest): Promise<ConnectorResponse> {
    try {
      logger.info('Calling connector service', { provider: request.provider, endpoint: request.endpoint });

      // Try to get Cloud Run identity token for IAM authentication (optional if service is public)
      const identityToken = await this.getIdentityToken(this.baseUrl);
      // Create application-level service token (required)
      const serviceToken = this.createServiceToken();

      // Build headers - include identity token if available, always include service token
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'X-Service-Token': serviceToken // Application-level service token
      };

      if (identityToken) {
        headers['Authorization'] = `Bearer ${identityToken}`; // Cloud Run IAM token (if available)
      }

      const response = await axios.post(
        `${this.baseUrl}/api/v1/connector/call`,
        request,
        {
          headers,
          timeout: 30000
        }
      );

      return response.data;
    } catch (error: any) {
      logger.error('Connector service call failed', error);
      
      return {
        success: false,
        error: {
          code: 'CONNECTOR_ERROR',
          message: error.message || 'Failed to call connector service',
          details: error.response?.data
        }
      };
    }
  }
}

