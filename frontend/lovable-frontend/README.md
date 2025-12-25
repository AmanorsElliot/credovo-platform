# Lovable Frontend

This directory contains the Lovable frontend project configuration.

## Setup

1. Create a new Lovable project at https://lovable.dev
2. Connect this GitHub repository
3. Configure Lovable Cloud authentication
4. Set environment variables:
   - `REACT_APP_API_URL`: Orchestration service URL
   - `REACT_APP_LOVABLE_AUTH_URL`: Lovable Cloud auth URL

## Environment Variables

The frontend will need to be configured with:
- API endpoint for the orchestration service
- Lovable Cloud authentication settings
- Feature flags for different environments

## Integration

The frontend should:
1. Authenticate users via Lovable Cloud
2. Send authenticated requests to the orchestration service
3. Handle JWT token refresh
4. Display KYC/KYB status and results

