import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';
import { createLogger } from '../utils/logger';

const logger = createLogger('auth');

export interface JwtPayload {
  sub: string;
  email?: string;
  iat?: number;
  exp?: number;
  [key: string]: any;
}

// Lovable Cloud JWT validation
// This will be configured with actual Lovable Cloud JWKS endpoint
const LOVABLE_JWKS_URI = process.env.LOVABLE_JWKS_URI || 'https://auth.lovable.dev/.well-known/jwks.json';
const LOVABLE_AUDIENCE = process.env.LOVABLE_AUDIENCE || 'credovo-api';

const client = jwksClient({
  jwksUri: LOVABLE_JWKS_URI,
  cache: true,
  cacheMaxAge: 86400000, // 24 hours
  rateLimit: true,
  jwksRequestsPerMinute: 10
});

function getKey(header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) {
      callback(err);
      return;
    }
    const signingKey = key?.getPublicKey();
    callback(null, signingKey);
  });
}

export function validateJwt(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logger.warn('Missing or invalid authorization header', {
      path: req.path,
      ip: req.ip
    });
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing or invalid authorization token'
    });
  }

  const token = authHeader.substring(7);

  jwt.verify(
    token,
    getKey,
    {
      audience: LOVABLE_AUDIENCE,
      issuer: process.env.LOVABLE_ISSUER || 'https://auth.lovable.dev',
      algorithms: ['RS256']
    },
    (err, decoded) => {
      if (err) {
        logger.warn('JWT validation failed', {
          error: err.message,
          path: req.path
        });
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'Invalid or expired token'
        });
      }

      // Attach user info to request
      req.user = decoded as JwtPayload;
      req.userId = (decoded as JwtPayload).sub;
      
      next();
    }
  );
}

// Supabase JWT validation using JWKS (preferred) or JWT Secret (fallback)
// Validates JWTs issued by Supabase (when using Supabase auth through Lovable)
// Supabase supports both RS256 (via JWKS) and HS256 (via JWT secret)
const SUPABASE_JWKS_URI = process.env.SUPABASE_JWKS_URI || (process.env.SUPABASE_URL 
  ? `${process.env.SUPABASE_URL}/auth/v1/.well-known/jwks.json`
  : null);

const supabaseJwksClient = SUPABASE_JWKS_URI ? jwksClient({
  jwksUri: SUPABASE_JWKS_URI,
  cache: true,
  cacheMaxAge: 86400000, // 24 hours
  rateLimit: true,
  jwksRequestsPerMinute: 10
}) : null;

function getSupabaseKey(header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) {
  if (!supabaseJwksClient) {
    callback(new Error('Supabase JWKS client not initialized'));
    return;
  }
  
  supabaseJwksClient.getSigningKey(header.kid, (err, key) => {
    if (err) {
      callback(err);
      return;
    }
    const signingKey = key?.getPublicKey();
    callback(null, signingKey);
  });
}

export function validateSupabaseJwt(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logger.warn('Missing or invalid authorization header', {
      path: req.path,
      ip: req.ip
    });
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing or invalid authorization token'
    });
  }

  const token = authHeader.substring(7);
  const supabaseJwtSecret = process.env.SUPABASE_JWT_SECRET;

  // Try JWKS first (RS256), then fall back to JWT secret (HS256)
  if (SUPABASE_JWKS_URI && supabaseJwksClient) {
    // Method 1: Validate using JWKS (RS256) - Preferred method
    jwt.verify(
      token,
      getSupabaseKey,
      {
        algorithms: ['RS256'],
        // Supabase tokens have 'authenticated' as audience
        audience: process.env.SUPABASE_AUDIENCE || 'authenticated'
      },
      (err, decoded) => {
        if (err) {
          // If JWKS validation fails and we have a JWT secret, try that
          if (supabaseJwtSecret) {
            try {
              const decodedSecret = jwt.verify(token, supabaseJwtSecret, {
                algorithms: ['HS256'],
                audience: process.env.SUPABASE_AUDIENCE || 'authenticated'
              }) as JwtPayload;
              
              req.user = decodedSecret;
              req.userId = decodedSecret.sub;
              logger.info('Supabase JWT validated using JWT secret (fallback)');
              return next();
            } catch (secretErr: any) {
              logger.warn('Supabase JWT validation failed (both JWKS and secret)', {
                jwksError: err.message,
                secretError: secretErr.message,
                path: req.path
              });
              return res.status(401).json({
                error: 'Unauthorized',
                message: 'Invalid or expired token'
              });
            }
          }
          
          logger.warn('Supabase JWT validation failed (JWKS)', {
            error: err.message,
            path: req.path
          });
          return res.status(401).json({
            error: 'Unauthorized',
            message: 'Invalid or expired token'
          });
        }

        // JWKS validation succeeded
        req.user = decoded as JwtPayload;
        req.userId = (decoded as JwtPayload).sub;
        logger.debug('Supabase JWT validated using JWKS');
        next();
      }
    );
  } else if (supabaseJwtSecret) {
    // Method 2: Validate using JWT secret (HS256) - Fallback
    try {
      const decoded = jwt.verify(token, supabaseJwtSecret, {
        algorithms: ['HS256'],
        audience: process.env.SUPABASE_AUDIENCE || 'authenticated'
      }) as JwtPayload;
      
      req.user = decoded;
      req.userId = decoded.sub;
      logger.debug('Supabase JWT validated using JWT secret');
      next();
    } catch (err: any) {
      logger.warn('Supabase JWT validation failed (JWT secret)', {
        error: err.message,
        path: req.path
      });
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Invalid or expired token'
      });
    }
  } else {
    logger.error('Supabase authentication not configured. Need SUPABASE_URL or SUPABASE_JWKS_URI (and optionally SUPABASE_JWT_SECRET)');
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Supabase authentication not configured. Set SUPABASE_URL or SUPABASE_JWKS_URI'
    });
  }
}

// Backend-issued JWT validation (for tokens we issue ourselves)
// This is used when Lovable doesn't provide JWTs - frontend exchanges user info for our JWT
export function validateBackendJwt(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logger.warn('Missing or invalid authorization header', {
      path: req.path,
      ip: req.ip
    });
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing or invalid authorization token'
    });
  }

  const token = authHeader.substring(7);
  const serviceSecret = process.env.SERVICE_JWT_SECRET;
  
  if (!serviceSecret) {
    logger.error('SERVICE_JWT_SECRET not configured');
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Authentication not configured'
    });
  }

  try {
    const decoded = jwt.verify(token, serviceSecret) as JwtPayload;
    
    // Attach user info to request
    req.user = decoded;
    req.userId = decoded.sub;
    
    next();
  } catch (err: any) {
    logger.warn('JWT validation failed', { 
      error: err.message,
      path: req.path 
    });
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid or expired token'
    });
  }
}

// Service-to-service JWT validation
// For inter-service communication using GCP service accounts
export function validateServiceJwt(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing service token'
    });
  }

  const token = authHeader.substring(7);
  
  // In production, this would validate against GCP service account tokens
  // For now, we'll use a shared secret for service-to-service auth
  const serviceSecret = process.env.SERVICE_JWT_SECRET;
  
  if (!serviceSecret) {
    logger.error('SERVICE_JWT_SECRET not configured');
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Service authentication not configured'
    });
  }

  try {
    const decoded = jwt.verify(token, serviceSecret) as { service: string; iat: number; exp: number };
    req.service = decoded.service;
    next();
  } catch (err) {
    logger.warn('Service JWT validation failed', { error: err });
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid service token'
    });
  }
}

// CORS configuration for Lovable frontend
export function configureCors() {
  const allowedOrigins = [
    process.env.LOVABLE_FRONTEND_URL || 'https://app.lovable.dev',
    process.env.FRONTEND_URL || 'http://localhost:3000'
  ];

  return (req: Request, res: Response, next: NextFunction) => {
    const origin = req.headers.origin;
    
    if (origin && allowedOrigins.includes(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Request-ID');
      res.setHeader('Access-Control-Allow-Credentials', 'true');
    }

    if (req.method === 'OPTIONS') {
      return res.sendStatus(200);
    }

    next();
  };
}

// Extend Express Request type
declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
      userId?: string;
      service?: string;
    }
  }
}

