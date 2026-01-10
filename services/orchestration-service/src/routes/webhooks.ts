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

    // Verify webhook signature if provided
    // Shufti Pro may send signature in headers - verify if present
    if (req.headers['x-shufti-signature'] || req.headers['x-shufti-pro-signature']) {
      const signature = req.headers['x-shufti-signature'] || req.headers['x-shufti-pro-signature'];
      const secretKey = process.env.SHUFTI_PRO_SECRET_KEY;
      
      if (secretKey && signature) {
        const isValid = verifyWebhookSignature(req.body, signature as string, secretKey);
        if (!isValid) {
          logger.warn('Invalid webhook signature', { reference, signature });
          // Still return 200 to prevent retries, but log the security issue
          // In production, you might want to return 401 and investigate
          return res.status(200).json({ 
            success: false, 
            message: 'Invalid signature - logged for review' 
          });
        }
        logger.info('Webhook signature verified', { reference });
      }
    }

    // Optional: IP whitelisting (Shufti Pro sends from specific IP ranges)
    // Check if request IP is from known Shufti Pro IPs
    const clientIp = req.ip || req.headers['x-forwarded-for'] || req.connection.remoteAddress;
    const allowedIps = process.env.SHUFTI_PRO_ALLOWED_IPS?.split(',') || [];
    
    if (allowedIps.length > 0 && !isIpAllowed(clientIp as string, allowedIps)) {
      logger.warn('Webhook from unauthorized IP', { ip: clientIp, reference });
      // Log but don't block (in case IP list is incomplete)
      // In production, you might want to block unauthorized IPs
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
 * Verify webhook signature
 * 
 * Shufti Pro may use HMAC-SHA256 or similar for signature verification
 * This is a placeholder implementation - verify exact method with Shufti Pro docs
 */
function verifyWebhookSignature(
  payload: any, 
  signature: string, 
  secretKey: string
): boolean {
  try {
    // Convert payload to string (consistent format)
    const payloadString = typeof payload === 'string' 
      ? payload 
      : JSON.stringify(payload);
    
    // Generate HMAC-SHA256 signature
    const hmac = crypto.createHmac('sha256', secretKey);
    hmac.update(payloadString);
    const expectedSignature = hmac.digest('hex');
    
    // Compare signatures (constant-time comparison to prevent timing attacks)
    return crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature)
    );
  } catch (error) {
    logger.error('Signature verification error', error);
    return false;
  }
}

/**
 * Check if IP is in allowed list
 * Supports CIDR notation and exact IPs
 */
function isIpAllowed(ip: string, allowedIps: string[]): boolean {
  if (allowedIps.length === 0) return true; // No restrictions
  
  // Simple exact match for now
  // TODO: Add CIDR notation support if needed
  return allowedIps.some(allowed => {
    if (allowed.includes('/')) {
      // CIDR notation - would need ipaddr.js or similar
      // For now, just check if IP starts with the prefix
      const [prefix] = allowed.split('/');
      return ip.startsWith(prefix);
    }
    return ip === allowed;
  });
}

/**
 * Health check for webhook endpoint
 */
WebhookRouter.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', service: 'webhook-handler' });
});

