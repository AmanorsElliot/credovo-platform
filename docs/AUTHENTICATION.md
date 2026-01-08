# Authentication Guide

## Overview

Since Lovable Cloud doesn't provide JWT tokens directly, we've implemented a **token exchange** pattern where:

1. Frontend authenticates users with Lovable Cloud (gets user info)
2. Frontend exchanges user info for a backend-issued JWT token
3. Frontend uses that JWT for all subsequent API requests

## Authentication Flow

```
┌─────────┐         ┌──────────────┐         ┌─────────────────┐
│ Frontend│         │ Lovable Cloud│         │ Backend API     │
└────┬────┘         └──────┬───────┘         └────────┬────────┘
     │                    │                           │
     │ 1. User Login      │                           │
     ├───────────────────>│                           │
     │                    │                           │
     │ 2. User Info       │                           │
     │<──────────────────┤                           │
     │                    │                           │
     │ 3. Exchange for JWT│                           │
     ├───────────────────────────────────────────────>│
     │    POST /api/v1/auth/token                     │
     │    { userId, email, name }                     │
     │                    │                           │
     │ 4. Backend JWT     │                           │
     │<───────────────────────────────────────────────┤
     │                    │                           │
     │ 5. API Requests    │                           │
     │    with JWT        │                           │
     ├───────────────────────────────────────────────>│
     │    Authorization: Bearer <token>               │
     │                    │                           │
     │ 6. API Response    │                           │
     │<───────────────────────────────────────────────┤
```

## Frontend Implementation

### Step 1: Get User Info from Lovable

Lovable provides user information after authentication. You'll need to access this through Lovable's SDK or API.

```typescript
// Example: Get user info from Lovable
// (Check Lovable docs for exact method)
const user = await lovable.getCurrentUser();
// Returns: { userId: "user-123", email: "user@example.com", name: "John Doe" }
```

### Step 2: Exchange for Backend JWT

```typescript
// Exchange Lovable user info for backend JWT
const response = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/auth/token`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    userId: user.userId,      // Required
    email: user.email,        // Optional
    name: user.name           // Optional
  })
});

const { token, expiresIn, user: userInfo } = await response.json();

// Store token (localStorage, sessionStorage, or state management)
localStorage.setItem('authToken', token);
```

### Step 3: Use JWT for API Requests

```typescript
// Make authenticated API requests
const token = localStorage.getItem('authToken');

const response = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/applications/123/kyc/initiate`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    type: 'individual',
    data: { /* ... */ }
  })
});
```

### Step 4: Handle Token Refresh

Tokens expire after 7 days. You can verify if a token is still valid:

```typescript
// Verify token
const response = await fetch(`${process.env.REACT_APP_API_URL}/api/v1/auth/verify`, {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});

const { valid, user } = await response.json();

if (!valid) {
  // Token expired or invalid - exchange for new token
  // Repeat Step 2
}
```

## Backend Endpoints

### POST `/api/v1/auth/token`

Exchange Lovable user info for a backend JWT token.

**Request:**
```json
{
  "userId": "user-123",      // Required
  "email": "user@example.com",  // Optional
  "name": "John Doe"         // Optional
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 604800,  // 7 days in seconds
  "user": {
    "id": "user-123",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

### GET `/api/v1/auth/verify`

Verify if a JWT token is still valid.

**Headers:**
```
Authorization: Bearer <token>
```

**Response (valid):**
```json
{
  "valid": true,
  "user": {
    "id": "user-123",
    "email": "user@example.com",
    "name": "John Doe"
  }
}
```

**Response (invalid):**
```json
{
  "valid": false,
  "error": "Invalid or expired token"
}
```

## Security Considerations

### Current Implementation

- **Token Exchange**: Frontend sends user info, backend issues JWT
- **No Verification**: Currently, we trust the frontend's user info
- **Token Storage**: Frontend stores JWT in localStorage/sessionStorage

### Recommended Enhancements

1. **Verify with Lovable API** (if available):
   ```typescript
   // In auth.ts, before issuing token:
   const isValid = await verifyWithLovable(userId, email);
   if (!isValid) {
     return res.status(401).json({ error: 'Invalid user' });
   }
   ```

2. **Add Rate Limiting**: Limit token exchange requests per IP/user

3. **Short-lived Tokens**: Consider shorter expiration (1 hour) with refresh tokens

4. **HTTPS Only**: Ensure all communication is over HTTPS

5. **Token Rotation**: Implement token refresh mechanism

## Environment Variables

Required backend environment variables:

- `SERVICE_JWT_SECRET`: Secret key for signing JWTs (set via Secret Manager)
- `LOVABLE_FRONTEND_URL`: Frontend URL for CORS (optional)

Frontend environment variables:

- `REACT_APP_API_URL`: Backend API URL (e.g., `https://orchestration-service-xxx.run.app`)

## Migration from Lovable JWT (if needed)

If Lovable later provides JWTs, you can:

1. Keep the token exchange endpoint for backward compatibility
2. Update `validateBackendJwt` to also accept Lovable JWTs
3. Or switch back to `validateJwt` (Lovable JWKS validation)

## Troubleshooting

### Token Exchange Fails

- Check that `SERVICE_JWT_SECRET` is set in Secret Manager
- Verify frontend is sending correct user info format
- Check backend logs for errors

### Token Validation Fails

- Ensure token is sent in `Authorization: Bearer <token>` header
- Check token hasn't expired (7 days)
- Verify `SERVICE_JWT_SECRET` matches between services

### CORS Errors

- Verify `LOVABLE_FRONTEND_URL` is set correctly
- Check frontend origin matches allowed origins
- Ensure CORS middleware is applied

