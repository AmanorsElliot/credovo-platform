import { KYCRequest, KYCResponse } from '@credovo/shared-types';
import { createLogger } from '@credovo/shared-utils/logger';
import { DataLakeService } from './data-lake-service';
import { PubSubService } from './pubsub-service';
import { ConnectorClient } from './connector-client';

const logger = createLogger('kyc-service');

export class KYCService {
  private dataLake: DataLakeService;
  private pubsub: PubSubService;
  private connector: ConnectorClient;

  constructor() {
    this.dataLake = new DataLakeService();
    this.pubsub = new PubSubService();
    this.connector = new ConnectorClient();
  }

  async initiateKYC(request: KYCRequest): Promise<KYCResponse> {
    logger.info('Initiating KYC process', {
      applicationId: request.applicationId,
      type: request.type
    });

    try {
      // Store initial request in data lake
      await this.dataLake.storeKYCRequest(request);

      // Call connector service to initiate verification with SumSub
      const connectorRequest = {
        provider: 'sumsub',
        endpoint: '/resources/applicants',
        method: 'POST' as const,
        body: {
          externalUserId: request.userId,
          info: {
            firstName: request.data.firstName,
            lastName: request.data.lastName,
            dateOfBirth: request.data.dateOfBirth,
            address: request.data.address
          }
        },
        retry: true
      };

      const connectorResponse = await this.connector.call(connectorRequest);

      if (!connectorResponse.success) {
        throw new Error(connectorResponse.error?.message || 'Connector call failed');
      }

      // Store response in data lake
      const response: KYCResponse = {
        applicationId: request.applicationId,
        status: 'pending',
        provider: 'sumsub',
        result: {
          score: connectorResponse.data?.reviewResult?.reviewStatus === 'approved' ? 100 : 0,
          checks: this.mapSumSubChecks(connectorResponse.data),
          metadata: connectorResponse.data
        },
        timestamp: new Date()
      };

      await this.dataLake.storeKYCResponse(response);

      // Publish event for async processing
      await this.pubsub.publishKYCEvent({
        applicationId: request.applicationId,
        event: 'kyc_initiated',
        status: 'pending',
        timestamp: new Date()
      });

      return response;
    } catch (error: any) {
      logger.error('KYC initiation failed', error);
      
      // Store error in data lake
      const errorResponse: KYCResponse = {
        applicationId: request.applicationId,
        status: 'requires_review',
        provider: 'sumsub',
        timestamp: new Date()
      };

      await this.dataLake.storeKYCResponse(errorResponse);

      throw error;
    }
  }

  async getKYCStatus(applicationId: string, userId: string): Promise<KYCResponse | null> {
    logger.info('Getting KYC status', { applicationId, userId });

    try {
      // Try to get from data lake
      const stored = await this.dataLake.getKYCResponse(applicationId);
      
      if (stored) {
        return stored;
      }

      // If not found, check with provider
      const connectorRequest = {
        provider: 'sumsub',
        endpoint: `/resources/applicants/${applicationId}`,
        method: 'GET' as const,
        retry: false
      };

      const connectorResponse = await this.connector.call(connectorRequest);

      if (connectorResponse.success) {
        const response: KYCResponse = {
          applicationId,
          status: this.mapSumSubStatus(connectorResponse.data),
          provider: 'sumsub',
          result: {
            score: connectorResponse.data?.reviewResult?.reviewStatus === 'approved' ? 100 : 0,
            checks: this.mapSumSubChecks(connectorResponse.data),
            metadata: connectorResponse.data
          },
          timestamp: new Date()
        };

        await this.dataLake.storeKYCResponse(response);
        return response;
      }

      return null;
    } catch (error: any) {
      logger.error('Failed to get KYC status', error);
      throw error;
    }
  }

  private mapSumSubStatus(data: any): 'pending' | 'approved' | 'rejected' | 'requires_review' {
    const status = data?.reviewResult?.reviewStatus;
    switch (status) {
      case 'approved':
        return 'approved';
      case 'rejected':
        return 'rejected';
      case 'pending':
        return 'pending';
      default:
        return 'requires_review';
    }
  }

  private mapSumSubChecks(data: any): any[] {
    // Map SumSub response to our check format
    const checks = [];
    
    if (data?.reviewResult) {
      checks.push({
        type: 'identity_verification',
        status: data.reviewResult.reviewStatus === 'approved' ? 'pass' : 'fail',
        message: data.reviewResult.reviewStatus
      });
    }

    return checks;
  }
}

