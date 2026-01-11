import crypto from 'crypto';
import { createLogger } from './logger';

const logger = createLogger('webhook-verifier');

/**
 * Verify Shufti Pro webhook signature
 * 
 * According to Shufti Pro documentation:
 * - For clients registered before March 15, 2023: SHA-256 hash of (payload + secret_key)
 * - For clients registered after March 15, 2023: SHA-256 hash of (payload + SHA-256(secret_key))
 * 
 * The signature is sent in the 'Signature' header (or 'x-shufti-signature' / 'x-shufti-pro-signature')
 */
export function verifyShuftiProSignature(
  payload: string | object,
  signature: string,
  secretKey: string,
  clientRegisteredAfterMarch2023: boolean = true
): boolean {
  try {
    // Convert payload to string (consistent format)
    const payloadString = typeof payload === 'string' 
      ? payload 
      : JSON.stringify(payload);
    
    let expectedSignature: string;
    
    if (clientRegisteredAfterMarch2023) {
      // For newer clients: SHA-256(payload + SHA-256(secret_key))
      const hashedSecret = crypto.createHash('sha256').update(secretKey).digest('hex');
      const hmac = crypto.createHmac('sha256', hashedSecret);
      hmac.update(payloadString);
      expectedSignature = hmac.digest('hex');
    } else {
      // For older clients: SHA-256(payload + secret_key)
      const hmac = crypto.createHmac('sha256', secretKey);
      hmac.update(payloadString);
      expectedSignature = hmac.digest('hex');
    }
    
    // Compare signatures (constant-time comparison to prevent timing attacks)
    const signatureBuffer = Buffer.from(signature, 'hex');
    const expectedBuffer = Buffer.from(expectedSignature, 'hex');
    
    // Handle different signature formats (hex string, base64, etc.)
    if (signatureBuffer.length !== expectedBuffer.length) {
      // Try base64 decoding if hex doesn't match
      try {
        const signatureBase64 = Buffer.from(signature, 'base64');
        if (signatureBase64.length === expectedBuffer.length) {
          return crypto.timingSafeEqual(signatureBase64, expectedBuffer);
        }
      } catch {
        // Not base64, continue with hex comparison
      }
      return false;
    }
    
    return crypto.timingSafeEqual(signatureBuffer, expectedBuffer);
  } catch (error: any) {
    logger.error('Signature verification error', error);
    return false;
  }
}

/**
 * Extract webhook signature from request headers
 */
export function extractSignature(headers: Record<string, string | string[] | undefined>): string | null {
  // Try multiple possible header names
  const signatureHeaders = [
    'signature',
    'x-shufti-signature',
    'x-shufti-pro-signature',
    'x-signature'
  ];
  
  for (const headerName of signatureHeaders) {
    const headerValue = headers[headerName];
    if (headerValue) {
      return Array.isArray(headerValue) ? headerValue[0] : headerValue;
    }
  }
  
  return null;
}

/**
 * Middleware factory for webhook signature verification
 */
export function createWebhookVerificationMiddleware(
  secretKeyEnvVar: string = 'SHUFTI_PRO_SECRET_KEY',
  clientRegisteredAfterMarch2023: boolean = true,
  requireSignature: boolean = false
) {
  return (req: any, res: any, next: any) => {
    const secretKey = process.env[secretKeyEnvVar];
    
    if (!secretKey) {
      if (requireSignature) {
        logger.warn('Webhook signature verification required but secret key not configured');
        return res.status(500).json({
          error: 'Internal Server Error',
          message: 'Webhook verification not configured'
        });
      }
      // If signature not required and secret not configured, skip verification
      logger.debug('Skipping webhook signature verification (secret not configured)');
      return next();
    }
    
    const signature = extractSignature(req.headers);
    
    if (!signature) {
      if (requireSignature) {
        logger.warn('Webhook signature required but not found in headers', {
          headers: Object.keys(req.headers)
        });
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'Webhook signature required'
        });
      }
      // If signature not required, log warning but continue
      logger.warn('Webhook signature not found in headers (continuing without verification)', {
        path: req.path
      });
      return next();
    }
    
    // Get raw body for signature verification
    // Note: This requires body-parser to be configured with verify option to preserve raw body
    const rawBody = (req as any).rawBody || JSON.stringify(req.body);
    
    const isValid = verifyShuftiProSignature(
      rawBody,
      signature,
      secretKey,
      clientRegisteredAfterMarch2023
    );
    
    if (!isValid) {
      logger.warn('Invalid webhook signature', {
        path: req.path,
        reference: req.body?.reference
      });
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid webhook signature'
      });
    }
    
    logger.debug('Webhook signature verified', {
      path: req.path,
      reference: req.body?.reference
    });
    
    next();
  };
}
