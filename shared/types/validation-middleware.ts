import { Request, Response, NextFunction } from 'express';
import { z, ZodError } from 'zod';

// Simple logger fallback if shared-utils is not available
const logger = {
  error: (...args: any[]) => console.error('[VALIDATION ERROR]', ...args),
  warn: (...args: any[]) => console.warn('[VALIDATION WARN]', ...args),
  info: (...args: any[]) => console.log('[VALIDATION INFO]', ...args),
};

/**
 * Validation middleware factory
 * Creates middleware that validates request body, query, or params against a Zod schema
 */
export function validateRequest(schema: {
  body?: z.ZodSchema;
  query?: z.ZodSchema;
  params?: z.ZodSchema;
}) {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      // Validate body if schema provided
      if (schema.body) {
        const result = schema.body.safeParse(req.body);
        if (!result.success) {
          return res.status(400).json({
            error: 'Validation Error',
            message: 'Invalid request body',
            details: formatZodErrors(result.error)
          });
        }
        // Replace body with validated (and potentially transformed) data
        req.body = result.data;
      }

      // Validate query if schema provided
      if (schema.query) {
        const result = schema.query.safeParse(req.query);
        if (!result.success) {
          return res.status(400).json({
            error: 'Validation Error',
            message: 'Invalid query parameters',
            details: formatZodErrors(result.error)
          });
        }
        // Replace query with validated data
        req.query = result.data as any;
      }

      // Validate params if schema provided
      if (schema.params) {
        const result = schema.params.safeParse(req.params);
        if (!result.success) {
          return res.status(400).json({
            error: 'Validation Error',
            message: 'Invalid URL parameters',
            details: formatZodErrors(result.error)
          });
        }
        // Replace params with validated data
        req.params = result.data as any;
      }

      next();
    } catch (error: any) {
      logger.error('Validation middleware error', error);
      return res.status(500).json({
        error: 'Internal Server Error',
        message: 'Validation failed'
      });
    }
  };
}

/**
 * Format Zod errors into a user-friendly structure
 */
function formatZodErrors(error: ZodError): Array<{ path: string; message: string }> {
  return error.issues.map((err: any) => ({
    path: err.path.join('.'),
    message: err.message
  }));
}

/**
 * Validate request body only
 */
export function validateBody<T extends z.ZodSchema>(schema: T) {
  return validateRequest({ body: schema });
}

/**
 * Validate query parameters only
 */
export function validateQuery<T extends z.ZodSchema>(schema: T) {
  return validateRequest({ query: schema });
}

/**
 * Validate URL parameters only
 */
export function validateParams<T extends z.ZodSchema>(schema: T) {
  return validateRequest({ params: schema });
}
