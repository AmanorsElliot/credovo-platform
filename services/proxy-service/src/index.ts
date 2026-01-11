import express, { Request, Response } from 'express';
import axios from 'axios';
import cors from 'cors';

const app = express();
const PORT = parseInt(process.env.PORT || '8080', 10);

// CORS configuration - allow requests from Supabase Edge Functions
const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  credentials: true,
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));
app.use(express.json());

// Target orchestration service URL
const ORCHESTRATION_SERVICE_URL = process.env.ORCHESTRATION_SERVICE_URL || 
  'https://orchestration-service-saz24fo3sa-ew.a.run.app';

// Health check
app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'healthy', service: 'proxy-service' });
});

// Proxy all requests to orchestration service
app.all('*', async (req: Request, res: Response) => {
  try {
    // Extract Supabase JWT from Authorization header
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Missing or invalid authorization header'
      });
    }

    const supabaseToken = authHeader.substring(7);

    // Get Cloud Run identity token for service-to-service authentication
    // This allows the proxy to authenticate to the orchestration service
    let identityToken: string | null = null;
    try {
      const metadataServerTokenUrl = 'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity';
      const tokenResponse = await axios.get(metadataServerTokenUrl, {
        params: {
          audience: ORCHESTRATION_SERVICE_URL
        },
        headers: {
          'Metadata-Flavor': 'Google'
        },
        timeout: 5000
      });
      identityToken = typeof tokenResponse.data === 'string' 
        ? tokenResponse.data.trim() 
        : tokenResponse.data;
    } catch (error: any) {
      console.warn('Failed to get identity token:', error.message);
      // Continue without identity token - orchestration service might be public
    }

    // Forward request to orchestration service
    const targetUrl = `${ORCHESTRATION_SERVICE_URL}${req.path}${req.url.includes('?') ? req.url.substring(req.url.indexOf('?')) : ''}`;
    
    const headers: Record<string, string> = {
      'Content-Type': req.headers['content-type'] || 'application/json',
      'X-User-Token': supabaseToken, // Forward Supabase JWT in X-User-Token header
    };

    // Add Cloud Run identity token if available
    if (identityToken) {
      headers['Authorization'] = `Bearer ${identityToken}`;
    }

    // Forward all other headers (except host, connection, etc.)
    Object.keys(req.headers).forEach(key => {
      const lowerKey = key.toLowerCase();
      if (!['host', 'connection', 'authorization', 'content-length'].includes(lowerKey)) {
        if (req.headers[key] && typeof req.headers[key] === 'string') {
          headers[key] = req.headers[key] as string;
        }
      }
    });

    const response = await axios({
      method: req.method,
      url: targetUrl,
      headers,
      data: req.body,
      timeout: 30000,
      validateStatus: () => true // Don't throw on any status
    });

    // Forward response
    res.status(response.status);
    Object.keys(response.headers).forEach(key => {
      const lowerKey = key.toLowerCase();
      if (!['content-encoding', 'transfer-encoding', 'connection'].includes(lowerKey)) {
        res.setHeader(key, response.headers[key] as string);
      }
    });
    res.json(response.data);
  } catch (error: any) {
    console.error('Proxy error:', error.message);
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to proxy request'
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Proxy service started on port ${PORT}`);
  console.log(`Proxying to: ${ORCHESTRATION_SERVICE_URL}`);
});
