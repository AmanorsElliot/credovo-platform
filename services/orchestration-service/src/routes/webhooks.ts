import { Router, Request, Response } from 'express';
import axios from 'axios';
import { createLogger } from '@credovo/shared-utils/logger';
import crypto from 'crypto';

const logger = createLogger('webhook-handler');
export const WebhookRouter = Router();

const KYC_SERVICE_URL = process.env.KYC_SERVICE_URL || 'http://kyc-kyb-service:8080';

/**
 * Shufti Pro Webhook Endpoint
 * 
 * Receives verification results from Shufti Pro asynchronously.
 * 
 * Webhook URL format: https://orchestration-service-url/api/v1/webhooks/shufti-pro
 * 
 * Security:
 * - Verify webhook signature (if provided by Shufti Pro)
 * - IP whitelisting (Shufti Pro sends from specific IPs)
 * - Always return 200 OK to acknowledge receipt
 * 
 * Reference: https://support.shuftipro.com/hc/en-us/articles/9511003514269-How-can-I-get-webhook-responses
 */
WebhookRouter.post('/shufti-pro', async (req: Request, res: Response) => {
  try {
    const webhookData = req.body;
    const reference = webhookData.reference || webhookData.event?.reference;
    
    logger.info('Received Shufti Pro webhook', {
      reference,
      event: webhookData.event,
      status: webhookData.verification_result?.event
    });

    // Verify webhook signature if provided (Shufti Pro may include signature)
    // Note: Check Shufti Pro documentation for signature verification method
    if (req.headers['x-shufti-signature']) {
      // TODO: Implement signature verification based on Shufti Pro documentation
      // const signature = req.headers['x-shufti-signature'];
      // const isValid = verifySignature(webhookData, signature);
      // if (!isValid) {
      //   logger.warn('Invalid webhook signature', { reference });
      //   return res.status(401).json({ error: 'Invalid signature' });
      // }
    }

    // Determine if this is a KYC or KYB verification based on reference
    const isKYB = reference?.startsWith('kyb-') || webhookData.business;
    const isKYC = reference?.startsWith('kyc-') || webhookData.document;

    if (isKYC) {
      // Forward to KYC service for processing
      await axios.post(
        `${KYC_SERVICE_URL}/api/v1/webhooks/shufti-pro`,
        webhookData,
        {
          headers: {
            'Authorization': `Bearer ${process.env.SERVICE_JWT_SECRET}`,
            'Content-Type': 'application/json'
          }
        }
      );
    } else if (isKYB) {
      // Forward to KYB service for processing
      await axios.post(
        `${KYC_SERVICE_URL}/api/v1/webhooks/shufti-pro-kyb`,
        webhookData,
        {
          headers: {
            'Authorization': `Bearer ${process.env.SERVICE_JWT_SECRET}`,
            'Content-Type': 'application/json'
          }
        }
      );
    } else {
      logger.warn('Unknown webhook type', { reference, webhookData });
    }

    // Always return 200 OK to acknowledge receipt
    // Shufti Pro will retry up to 10 times if not acknowledged
    res.status(200).json({ 
      success: true, 
      message: 'Webhook received and processed' 
    });

  } catch (error: any) {
    logger.error('Webhook processing failed', error, {
      body: req.body,
      headers: req.headers
    });

    // Still return 200 OK to prevent retries for processing errors
    // Log the error for manual review
    res.status(200).json({ 
      success: false, 
      message: 'Webhook received but processing failed',
      error: error.message 
    });
  }
});

/**
 * Health check for webhook endpoint
 */
WebhookRouter.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', service: 'webhook-handler' });
});

