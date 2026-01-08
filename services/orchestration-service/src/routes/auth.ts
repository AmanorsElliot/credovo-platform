import { Router, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { createLogger } from '@credovo/shared-utils/logger';

const logger = createLogger('orchestration-service');
export const AuthRouter = Router();

// Token exchange endpoint
// Frontend sends Lovable user info, backend issues its own JWT
AuthRouter.post('/token', async (req: Request, res: Response) => {
  try {
    const { userId, email, name } = req.body;

    // Validate required fields
    if (!userId) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'userId is required'
      });
    }

    // Optional: Verify with Lovable API if you have an API key
    // For now, we'll trust the frontend (you can add verification later)
    const serviceSecret = process.env.SERVICE_JWT_SECRET;
    
    if (!serviceSecret) {
      logger.error('SERVICE_JWT_SECRET not configured');
      return res.status(500).json({
        error: 'Internal Server Error',
        message: 'Authentication service not configured'
      });
    }

    // Issue our own JWT token
    const token = jwt.sign(
      {
        sub: userId,
        email: email || undefined,
        name: name || undefined,
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60) // 7 days
      },
      serviceSecret,
      {
        algorithm: 'HS256'
      }
    );

    logger.info('Token issued', { userId, email });

    res.json({
      token,
      expiresIn: 7 * 24 * 60 * 60, // 7 days in seconds
      user: {
        id: userId,
        email: email || undefined,
        name: name || undefined
      }
    });
  } catch (error: any) {
    logger.error('Failed to issue token', error);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to issue token'
    });
  }
});

// Verify token endpoint (for frontend to check if token is still valid)
AuthRouter.get('/verify', async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        valid: false,
        error: 'Missing or invalid authorization header'
      });
    }

    const token = authHeader.substring(7);
    const serviceSecret = process.env.SERVICE_JWT_SECRET;

    if (!serviceSecret) {
      return res.status(500).json({
        valid: false,
        error: 'Authentication service not configured'
      });
    }

    try {
      const decoded = jwt.verify(token, serviceSecret) as any;
      res.json({
        valid: true,
        user: {
          id: decoded.sub,
          email: decoded.email,
          name: decoded.name
        }
      });
    } catch (err) {
      res.status(401).json({
        valid: false,
        error: 'Invalid or expired token'
      });
    }
  } catch (error: any) {
    logger.error('Failed to verify token', error);
    res.status(500).json({
      valid: false,
      error: 'Internal Server Error'
    });
  }
});

