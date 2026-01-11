import { Router, Request, Response } from 'express';
import axios from 'axios';
import jwt from 'jsonwebtoken';
import { createLogger } from '@credovo/shared-utils/logger';
import { verifyShuftiProSignature, extractSignature } from '@credovo/shared-utils/webhook-verifier';

const logger = createLogger('webhook-handler');
export const WebhookRouter = Router();

const KYC_SERVICE_URL = process.env.KYC_SERVICE_URL || 'http://kyc-kyb-service:8080';

// Helper function to get Cloud Run identity token for service-to-service calls
async function getIdentityToken(audience: string): Promise<string | null> {
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

// Helper function to create a service-to-service JWT token (fallback)
function createServiceToken(): string {
  const serviceSecret = process.env.SERVICE_JWT_SECRET;
  if (!serviceSecret) {
    throw new Error('SERVICE_JWT_SECRET not configured');
  }
  
  return jwt.sign(
    {
      service: 'orchestration-service',
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + 300 // 5 minutes
    },
    serviceSecret,
    { algorithm: 'HS256' }
  );
}

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
    const secretKey = process.env.SHUFTI_PRO_SECRET_KEY;
    const signature = extractSignature(req.headers);
    
    if (secretKey && signature) {
      // Get raw body for signature verification (preserved by middleware)
      const rawBody = (req as any).rawBody || JSON.stringify(req.body);
      const isValid = verifyShuftiProSignature(
        rawBody,
        signature,
        secretKey,
        true // Assume client registered after March 2023
      );
      
      if (!isValid) {
        logger.warn('Invalid webhook signature', { reference, signature });
        // Return 401 to reject invalid webhooks
        return res.status(401).json({ 
          success: false, 
          message: 'Invalid webhook signature' 
        });
      }
      logger.info('Webhook signature verified', { reference });
    } else if (secretKey && !signature) {
      // Secret configured but no signature - log warning
      logger.warn('Webhook signature expected but not found', { reference });
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

    // Try to get Cloud Run identity token for IAM authentication (optional if service is public)
    const identityToken = await getIdentityToken(KYC_SERVICE_URL);
    // Create application-level service token (required)
    const serviceToken = createServiceToken();
    
    // Build headers - include identity token if available, always include service token
    const headers: Record<string, string> = {
      'X-Service-Token': serviceToken, // Application-level service token
      'Content-Type': 'application/json'
    };
    
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`; // Cloud Run IAM token (if available)
    }
    
    if (isKYC) {
      // Forward to KYC service for processing
      await axios.post(
        `${KYC_SERVICE_URL}/api/v1/webhooks/shufti-pro`,
        webhookData,
        {
          headers
        }
      );
    } else if (isKYB) {
      // Forward to KYB service for processing
      await axios.post(
        `${KYC_SERVICE_URL}/api/v1/webhooks/shufti-pro-kyb`,
        webhookData,
        {
          headers
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
 * Plaid Webhook Endpoint
 * POST /api/v1/webhooks/plaid
 * 
 * Handles webhooks from Plaid for:
 * - Transaction updates
 * - Income verification status
 * - Account updates
 * - Item errors
 * 
 * Reference: https://plaid.com/docs/api/webhooks/
 */
WebhookRouter.post('/plaid', async (req: Request, res: Response) => {
  try {
    const webhook = req.body;
    
    logger.info('Received Plaid webhook', {
      webhook_type: webhook.webhook_type,
      webhook_code: webhook.webhook_code,
      item_id: webhook.item_id,
    });

    // Verify webhook signature (Plaid uses HMAC-SHA256)
    // Note: Plaid webhook verification requires the raw body
    const plaidVerificationKey = process.env.PLAID_WEBHOOK_VERIFICATION_KEY;
    if (plaidVerificationKey && req.rawBody) {
      // Plaid webhook verification would go here
      // For now, we'll log and process
      logger.debug('Plaid webhook signature verification (to be implemented)');
    }

    // Process webhook based on type
    const webhookType = webhook.webhook_type;
    const webhookCode = webhook.webhook_code;

    // Handle different webhook types
    switch (webhookType) {
      case 'TRANSACTIONS':
        if (webhookCode === 'INITIAL_UPDATE' || webhookCode === 'HISTORICAL_UPDATE' || webhookCode === 'DEFAULT_UPDATE') {
          logger.info('Transaction update received', {
            new_transactions: webhook.new_transactions,
            item_id: webhook.item_id,
          });
          // Publish event to Pub/Sub for async processing
          // TODO: Implement Pub/Sub event publishing
        }
        break;
      
      case 'INCOME':
        if (webhookCode === 'VERIFICATION_COMPLETE') {
          logger.info('Income verification complete', {
            item_id: webhook.item_id,
          });
          // Publish event to Pub/Sub for async processing
          // TODO: Implement Pub/Sub event publishing
        }
        break;
      
      case 'ITEM':
        if (webhookCode === 'ERROR') {
          logger.error('Plaid item error', {
            item_id: webhook.item_id,
            error: webhook.error,
          });
        }
        break;
      
      default:
        logger.info('Unhandled Plaid webhook type', {
          webhook_type: webhookType,
          webhook_code: webhookCode,
        });
    }

    // Store webhook in data lake
    // TODO: Implement data lake storage

    res.status(200).json({ received: true });
  } catch (error: any) {
    logger.error('Failed to process Plaid webhook', error);
    res.status(500).json({ error: 'Failed to process webhook' });
  }
});

/**
 * Health check for webhook endpoint
 */
WebhookRouter.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', service: 'webhook-handler' });
});

