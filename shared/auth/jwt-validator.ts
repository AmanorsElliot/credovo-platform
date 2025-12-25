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

