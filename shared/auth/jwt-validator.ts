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

// Initialize JWKS client lazily to avoid startup failures
let client: ReturnType<typeof jwksClient> | null = null;

function getJwksClient(): ReturnType<typeof jwksClient> {
  if (!client) {
    client = jwksClient({
      jwksUri: LOVABLE_JWKS_URI,
      cache: true,
      cacheMaxAge: 86400000, // 24 hours
      rateLimit: true,
      jwksRequestsPerMinute: 10
    });
  }
  return client;
}

function getKey(header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) {
  const jwks = getJwksClient();
  jwks.getSigningKey(header.kid, (err, key) => {
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
// Supabase uses ES256 (Elliptic Curve) by default, but also supports RS256 and HS256
const SUPABASE_JWKS_URI = process.env.SUPABASE_JWKS_URI || (process.env.SUPABASE_URL 
  ? `${process.env.SUPABASE_URL}/auth/v1/.well-known/jwks.json`
  : null);

// Note: jwks-rsa primarily supports RSA keys, but can work with EC keys via getPublicKey()
// For ES256, we'll fetch the JWKS and convert EC keys appropriately
// Initialize Supabase JWKS client lazily to avoid startup failures
let supabaseJwksClient: ReturnType<typeof jwksClient> | null = null;

function getSupabaseJwksClient(): ReturnType<typeof jwksClient> | null {
  if (!SUPABASE_JWKS_URI) {
    return null;
  }
  if (!supabaseJwksClient) {
    supabaseJwksClient = jwksClient({
      jwksUri: SUPABASE_JWKS_URI,
      cache: true,
      cacheMaxAge: 86400000, // 24 hours
      rateLimit: true,
      jwksRequestsPerMinute: 10
    });
  }
  return supabaseJwksClient;
}

function getSupabaseKey(header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) {
  const jwks = getSupabaseJwksClient();
  if (!jwks) {
    callback(new Error('Supabase JWKS client not initialized'));
    return;
  }
  
  jwks.getSigningKey(header.kid, (err, key) => {
    if (err) {
      callback(err);
      return;
    }
    // getPublicKey() works for both RSA and EC keys
    const signingKey = key?.getPublicKey();
    callback(null, signingKey);
  });
}

export function validateSupabaseJwt(req: Request, res: Response, next: NextFunction) {
  // Check X-User-Token first (for dual auth: gcloud token in Authorization, JWT in X-User-Token)
  // Then check Authorization header as fallback
  // This allows gcloud identity tokens for IAM while using JWT for app auth
  let token: string | undefined;
  
  if (req.headers['x-user-token']) {
    // Prioritize X-User-Token header (used when gcloud token is in Authorization)
    token = req.headers['x-user-token'] as string;
    logger.debug('Using X-User-Token header for JWT validation');
  } else {
    // Fallback to Authorization header if X-User-Token is not present
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7);
    }
  }
  
  if (!token) {
    logger.warn('Missing or invalid authorization header', {
      path: req.path,
      ip: req.ip,
      hasAuthHeader: !!req.headers.authorization,
      authHeaderPrefix: req.headers.authorization?.substring(0, 20) || 'none'
    });
    console.error('[JWT] Missing token:', {
      path: req.path,
      hasAuthHeader: !!req.headers.authorization,
      authHeaderPrefix: req.headers.authorization?.substring(0, 20) || 'none'
    });
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing or invalid authorization token'
    });
  }
  const supabaseJwtSecret = process.env.SUPABASE_JWT_SECRET;

  // Try JWKS first (ES256/RS256), then fall back to JWT secret (HS256)
  const jwks = getSupabaseJwksClient();
  if (SUPABASE_JWKS_URI && jwks) {
    // Method 1: Validate using JWKS (ES256 or RS256) - Preferred method
    // Supabase uses ES256 (Elliptic Curve) by default
    jwt.verify(
      token,
      getSupabaseKey,
      {
        algorithms: ['ES256', 'RS256'], // Support both ES256 (Supabase default) and RS256
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
            errorName: err.name,
            path: req.path,
            tokenPrefix: token.substring(0, 20) + '...',
            jwksUri: SUPABASE_JWKS_URI
          });
          console.error('[JWT] Supabase JWT validation failed:', {
            error: err.message,
            errorName: err.name,
            path: req.path,
            jwksUri: SUPABASE_JWKS_URI
          });
          return res.status(401).json({
            error: 'Unauthorized',
            message: 'Invalid or expired token',
            details: process.env.NODE_ENV === 'development' ? err.message : undefined
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
  // Check X-User-Token first (for dual auth: gcloud token in Authorization, JWT in X-User-Token)
  // Then check Authorization header as fallback
  // This allows gcloud identity tokens for IAM while using JWT for app auth
  let token: string | undefined;
  
  if (req.headers['x-user-token']) {
    // Prioritize X-User-Token header (used when gcloud token is in Authorization)
    token = req.headers['x-user-token'] as string;
    logger.debug('Using X-User-Token header for JWT validation');
  } else {
    // Fallback to Authorization header if X-User-Token is not present
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7);
    }
  }
  
  if (!token) {
    logger.warn('Missing or invalid authorization header', {
      path: req.path,
      ip: req.ip
    });
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing or invalid authorization token'
    });
  }
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
// Supports dual authentication: Cloud Run IAM token in Authorization + app token in X-Service-Token
export function validateServiceJwt(req: Request, res: Response, next: NextFunction) {
  // Check X-Service-Token first (application-level service token)
  // Cloud Run IAM token in Authorization is handled by Cloud Run itself
  let token: string | undefined;
  
  if (req.headers['x-service-token']) {
    // Prioritize X-Service-Token header (application-level service token)
    token = req.headers['x-service-token'] as string;
    logger.debug('Using X-Service-Token header for service JWT validation');
  } else {
    // Fallback to Authorization header if X-Service-Token is not present
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7);
    }
  }
  
  if (!token) {
    // If no token at all, check if Cloud Run IAM already authenticated
    // (Cloud Run handles IAM authentication before the request reaches us)
    // In this case, we can allow the request if it's from an authenticated service
    logger.debug('No service token found, but Cloud Run IAM may have authenticated');
    // For now, require a token - we can relax this later if needed
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing service token'
    });
  }
  
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

