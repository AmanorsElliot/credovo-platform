import { Router, Request, Response } from 'express';
import { createLogger } from '@credovo/shared-utils/logger';
import { KYCService } from '../services/kyc-service';
import { KYBService } from '../services/kyb-service';
import { DataLakeService } from '../services/data-lake-service';
import { PubSubService } from '../services/pubsub-service';
import { KYCResponse, KYBResponse } from '@credovo/shared-types';

const logger = createLogger('webhook-handler');
export const WebhookRouter = Router();

const kycService = new KYCService();
const kybService = new KYBService();
const dataLake = new DataLakeService();

/**
 * Shufti Pro Webhook Handler for KYC
 * 
 * Receives verification results from Shufti Pro and updates the system.
 * This endpoint is called by the orchestration service after receiving the webhook.
 */
WebhookRouter.post('/shufti-pro', async (req: Request, res: Response) => {
  try {
    const webhookData = req.body;
    const reference = webhookData.reference || webhookData.event?.reference;
    const event = webhookData.event || webhookData.verification_result?.event;
    
    logger.info('Processing Shufti Pro KYC webhook', {
      reference,
      event,
      status: webhookData.verification_result?.event
    });

    // Extract application ID from reference (format: kyc-{applicationId}-{timestamp})
    const applicationIdMatch = reference?.match(/^kyc-([^-]+)-/);
    const applicationId = applicationIdMatch ? applicationIdMatch[1] : null;

    if (!applicationId) {
      logger.warn('Could not extract application ID from reference', { reference });
      return res.status(400).json({ error: 'Invalid reference format' });
    }

    // Store raw webhook data in data lake
    await dataLake.storeRawWebhook('kyc', applicationId, webhookData);

    // Map Shufti Pro response to our format
    const verificationResult = webhookData.verification_result || webhookData;
    const isApproved = event === 'verification.accepted' || event === 'approved';
    const isPending = event === 'verification.pending' || event === 'pending';

    // Update KYC response in data lake
    const kycResponse: KYCResponse = {
      applicationId,
      status: (isApproved ? 'approved' : 
              isPending ? 'pending' : 'rejected') as 'pending' | 'approved' | 'rejected' | 'requires_review',
      provider: 'shufti-pro',
      result: {
        score: isApproved ? 100 : 0,
        checks: extractChecks(verificationResult),
        metadata: webhookData,
        // Include AML screening results if available
        aml: verificationResult.risk_assessment || webhookData.risk_assessment
      },
      timestamp: new Date()
    };

    await dataLake.storeKYCResponse(kycResponse);

    // Publish event to Pub/Sub
    const pubsub = (await import('../services/pubsub-service')).PubSubService;
    const pubsubService = new pubsub();
    await pubsubService.publishKYCEvent({
      applicationId,
      event: isApproved ? 'kyc_approved' : isPending ? 'kyc_pending' : 'kyc_rejected',
      status: kycResponse.status,
      timestamp: new Date(),
      amlResults: verificationResult.risk_assessment
    });

    res.status(200).json({ success: true, message: 'Webhook processed' });

  } catch (error: any) {
    logger.error('Webhook processing failed', error, {
      body: req.body
    });
    
    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message
    });
  }
});

/**
 * Shufti Pro Webhook Handler for KYB
 */
WebhookRouter.post('/shufti-pro-kyb', async (req: Request, res: Response) => {
  try {
    const webhookData = req.body;
    const reference = webhookData.reference || webhookData.event?.reference;
    const event = webhookData.event || webhookData.verification_result?.event;
    
    logger.info('Processing Shufti Pro KYB webhook', {
      reference,
      event
    });

    // Extract application ID from reference (format: kyb-{applicationId}-{timestamp})
    const applicationIdMatch = reference?.match(/^kyb-([^-]+)-/);
    const applicationId = applicationIdMatch ? applicationIdMatch[1] : null;

    if (!applicationId) {
      logger.warn('Could not extract application ID from reference', { reference });
      return res.status(400).json({ error: 'Invalid reference format' });
    }

    // Store raw webhook data in data lake
    await dataLake.storeRawWebhook('kyb', applicationId, webhookData);

    // Map Shufti Pro response to our format
    const verificationResult = webhookData.verification_result || webhookData;
    const isVerified = event === 'verification.accepted' || event === 'approved';
    const isPending = event === 'verification.pending' || event === 'pending';

    // Update KYB response in data lake
    const kybResponse: KYBResponse = {
      applicationId,
      companyNumber: webhookData.business?.registration_number || '',
      status: (isVerified ? 'verified' : 
              isPending ? 'pending' : 'not_found') as 'verified' | 'pending' | 'not_found' | 'error',
      data: {
        companyName: webhookData.business?.name,
        status: event || 'unknown',
        metadata: webhookData,
        // Include AML screening results if available
        aml: verificationResult.risk_assessment || webhookData.risk_assessment
      },
      timestamp: new Date()
    };

    await dataLake.storeKYBResponse(kybResponse);

    // Publish event to Pub/Sub
    const pubsubService = new PubSubService();
    await pubsubService.publishKYBEvent({
      applicationId,
      event: isVerified ? 'kyb_verified' : isPending ? 'kyb_pending' : 'kyb_rejected',
      status: kybResponse.status,
      timestamp: new Date(),
      amlResults: verificationResult.risk_assessment
    });

    res.status(200).json({ success: true, message: 'Webhook processed' });

  } catch (error: any) {
    logger.error('KYB webhook processing failed', error, {
      body: req.body
    });
    
    res.status(500).json({
      error: 'Internal Server Error',
      message: error.message
    });
  }
});

/**
 * Helper function to extract verification checks from Shufti Pro response
 */
function extractChecks(verificationResult: any): any[] {
  const checks = [];
  
  if (verificationResult?.document) {
    checks.push({
      type: 'document_verification',
      status: verificationResult.document.verification_status === 'approved' ? 'pass' : 'fail',
      message: verificationResult.document.verification_status
    });
  }
  
  if (verificationResult?.face) {
    checks.push({
      type: 'face_verification',
      status: verificationResult.face.verification_status === 'approved' ? 'pass' : 'fail',
      message: verificationResult.face.verification_status
    });
  }
  
  if (verificationResult?.risk_assessment) {
    checks.push({
      type: 'aml_screening',
      status: verificationResult.risk_assessment.verification_status === 'approved' ? 'pass' : 'fail',
      message: verificationResult.risk_assessment.verification_status,
      riskScore: verificationResult.risk_assessment.risk_score,
      flags: verificationResult.risk_assessment.flags
    });
  }
  
  return checks;
}

