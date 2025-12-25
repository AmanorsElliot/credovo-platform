import axios from 'axios';
import { ConnectorRequest, ConnectorResponse } from '@credovo/shared-types';
import { createLogger } from '@credovo/shared-utils/logger';

const logger = createLogger('connector-client');

export class ConnectorClient {
  private baseUrl: string;

  constructor() {
    this.baseUrl = process.env.CONNECTOR_SERVICE_URL || 'http://connector-service:8080';
  }

  async call(request: ConnectorRequest): Promise<ConnectorResponse> {
    try {
      logger.info('Calling connector service', { provider: request.provider, endpoint: request.endpoint });

      const response = await axios.post(
        `${this.baseUrl}/api/v1/connector/call`,
        request,
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${process.env.SERVICE_JWT_SECRET}`
          },
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

