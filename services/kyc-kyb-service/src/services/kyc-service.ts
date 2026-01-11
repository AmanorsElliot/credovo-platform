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

      // Build callback URL for webhook (Shufti Pro will call this when verification completes)
      const orchestrationServiceUrl = process.env.ORCHESTRATION_SERVICE_URL || 'https://orchestration-service-saz24fo3sa-ew.a.run.app';
      const callbackUrl = `${orchestrationServiceUrl}/api/v1/webhooks/shufti-pro`;

      // Call connector service to initiate verification with Shufti Pro (primary provider)
      const connectorRequest = {
        provider: 'shufti-pro',
        endpoint: '/',
        method: 'POST' as const,
        body: {
          reference: `kyc-${request.applicationId}-${Date.now()}`,
          callback_url: callbackUrl, // Webhook URL for async results
          email: request.data.email || '',
          country: request.data.country || 'GB',
          language: 'EN',
          verification_mode: 'any',
          firstName: request.data.firstName,
          lastName: request.data.lastName,
          dateOfBirth: request.data.dateOfBirth,
          address: request.data.address,
          info: {
            firstName: request.data.firstName,
            lastName: request.data.lastName,
            dateOfBirth: request.data.dateOfBirth,
            address: request.data.address
          },
          // Enable AML screening
          aml_ongoing: 0 // Set to 1 for ongoing monitoring
        },
        retry: true
      };

      // Store raw API request in data lake
      await this.dataLake.storeRawAPIRequest('kyc', request.applicationId, {
        ...connectorRequest,
        timestamp: new Date()
      });

      const connectorResponse = await this.connector.call(connectorRequest);

      // Store raw API response in data lake
      await this.dataLake.storeRawAPIResponse('kyc', request.applicationId, {
        ...connectorResponse,
        timestamp: new Date()
      });

      if (!connectorResponse.success) {
        throw new Error(connectorResponse.error?.message || 'Connector call failed');
      }

      // Store response in data lake
      // Map Shufti Pro response format
      const verificationStatus = connectorResponse.event || connectorResponse.status;
      const isApproved = verificationStatus === 'verification.accepted' || 
                        verificationStatus === 'approved' ||
                        connectorResponse.verification_result?.event === 'verification.accepted';
      const isRejected = verificationStatus === 'verification.declined' || 
                        verificationStatus === 'verification.rejected' ||
                        verificationStatus === 'rejected' ||
                        connectorResponse.verification_result?.event === 'verification.declined';
      const isPending = verificationStatus === 'verification.pending' || 
                       verificationStatus === 'pending' ||
                       (!isApproved && !isRejected); // Default to pending if no clear status (async processing)

      const response: KYCResponse = {
        applicationId: request.applicationId,
        status: (isApproved ? 'approved' : 
                isRejected ? 'rejected' :
                isPending ? 'pending' : 'pending') as 'pending' | 'approved' | 'rejected' | 'requires_review',
        provider: 'shufti-pro',
        result: {
          score: isApproved ? 100 : 0,
          checks: this.mapShuftiProChecks(connectorResponse),
          metadata: connectorResponse,
          aml: connectorResponse.risk_assessment || connectorResponse.verification_result?.risk_assessment
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
        provider: 'shufti-pro',
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

      // If not found, check with provider (Shufti Pro)
      // Get the reference from the stored API request
      const rawRequest = await this.dataLake.getRawAPIRequest('kyc', applicationId);
      let reference: string;
      
      if (rawRequest && rawRequest.body && rawRequest.body.reference) {
        reference = rawRequest.body.reference;
      } else {
        // Fallback: construct reference from applicationId (format: kyc-{applicationId}-{timestamp})
        // This won't work for status checks but provides a fallback
        reference = `kyc-${applicationId}`;
        logger.warn('Could not find stored reference, using fallback', { applicationId, reference });
      }
      
      const connectorRequest = {
        provider: 'shufti-pro',
        endpoint: `/status/${reference}`,
        method: 'POST' as const,
        body: {
          reference: reference
        },
        retry: true  // Enable retry for status checks
      };

      try {
        const connectorResponse = await this.connector.call(connectorRequest);

        if (connectorResponse.success && connectorResponse.reference) {
          const verificationResult = connectorResponse.verification_result || connectorResponse;
          const verificationStatus = connectorResponse.event || 
                                    verificationResult.event || 
                                    connectorResponse.status;
          const isApproved = verificationStatus === 'verification.accepted' || 
                            verificationStatus === 'approved';
          
          const response: KYCResponse = {
            applicationId,
            status: (isApproved ? 'approved' : 
                    verificationStatus === 'verification.pending' || verificationStatus === 'pending' ? 'pending' : 'rejected') as 'pending' | 'approved' | 'rejected' | 'requires_review',
            provider: 'shufti-pro',
            result: {
              score: isApproved ? 100 : 0,
              checks: this.mapShuftiProChecks(verificationResult),
              metadata: connectorResponse,
              aml: verificationResult.risk_assessment || connectorResponse.risk_assessment
            },
            timestamp: new Date()
          };

          await this.dataLake.storeKYCResponse(response);
          return response;
        }

        // If status check failed, return null (application not found)
        logger.warn('Status check returned no data', { applicationId, reference, response: connectorResponse });
        return null;
      } catch (error: any) {
        logger.error('Status check failed', error, { applicationId, reference });
        // Don't throw - return null to indicate not found
        return null;
      }
    } catch (error: any) {
      logger.error('Failed to get KYC status', error);
      throw error;
    }
  }

  private mapShuftiProChecks(data: any): any[] {
    // Map Shufti Pro response to our check format
    const checks = [];
    
    const verificationResult = data?.verification_result || data;
    const event = data?.event || verificationResult?.event;
    
    if (verificationResult?.document) {
      checks.push({
        type: 'document_verification',
        status: event === 'verification.accepted' ? 'pass' : 
                event === 'verification.declined' ? 'fail' : 'pending',
        message: verificationResult.document?.verification_status || event
      });
    }
    
    if (verificationResult?.face) {
      checks.push({
        type: 'face_verification',
        status: event === 'verification.accepted' ? 'pass' : 
                event === 'verification.declined' ? 'fail' : 'pending',
        message: verificationResult.face?.verification_status || event
      });
    }
    
    if (verificationResult?.address) {
      checks.push({
        type: 'address_verification',
        status: event === 'verification.accepted' ? 'pass' : 
                event === 'verification.declined' ? 'fail' : 'pending',
        message: verificationResult.address?.verification_status || event
      });
    }
    
    // Fallback to general verification status
    if (checks.length === 0 && event) {
      checks.push({
        type: 'identity_verification',
        status: event === 'verification.accepted' ? 'pass' : 
                event === 'verification.declined' ? 'fail' : 'pending',
        message: event
      });
    }

    return checks;
  }

  // Keep SumSub mapping methods for backward compatibility/fallback
  // Note: mapSumSubStatus was removed as duplicate - use mapShuftiProStatus if needed

  private mapSumSubChecks(data: any): any[] {
    // Map SumSub response to our check format (kept for fallback)
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

