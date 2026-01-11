# Application Creation Endpoint

## Overview

A new `POST /api/v1/applications` endpoint has been added to create new applications. This resolves the 401 error when the frontend tries to create an application.

## Endpoint Details

### Create Application
- **Method**: `POST`
- **Path**: `/api/v1/applications`
- **Authentication**: Required (Supabase JWT or Backend JWT)
- **Content-Type**: `application/json`

### Request Body

```json
{
  "type": "business_mortgage",
  "data": {
    // Additional application data
  }
}
```

### Response (201 Created)

```json
{
  "success": true,
  "application": {
    "id": "app-1234567890-abc123",
    "userId": "user-123",
    "status": "pending",
    "createdAt": "2024-01-11T20:00:00.000Z",
    "updatedAt": "2024-01-11T20:00:00.000Z",
    "data": {
      "type": "business_mortgage"
    }
  }
}
```

### Error Responses

**401 Unauthorized** - Missing or invalid authentication token
```json
{
  "error": "Unauthorized",
  "message": "Missing or invalid authorization token"
}
```

**500 Internal Server Error** - Server error
```json
{
  "error": "Failed to create application",
  "message": "Error details"
}
```

## Usage Example

### From Frontend (Supabase JWT)

```typescript
const response = await fetch(`${API_URL}/api/v1/applications`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${supabaseToken}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    type: 'business_mortgage',
    data: {
      // Additional data
    }
  })
});

const { application } = await response.json();
console.log('Application created:', application.id);
```

### From Edge Function

```typescript
const backendResponse = await fetch(`${backendUrl}/api/v1/applications`, {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${token}`, // User's Supabase JWT
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    type: "business_mortgage",
    data: {}
  }),
});

const { application } = await backendResponse.json();
```

## Application ID Generation

The endpoint automatically generates a unique application ID in the format:
```
app-{timestamp}-{random}
```

Example: `app-1705008000000-abc123xyz`

## Next Steps After Creation

After creating an application, you can:

1. **Initiate KYC**: `POST /api/v1/applications/{applicationId}/kyc/initiate`
2. **Initiate KYB**: `POST /api/v1/applications/{applicationId}/kyb/verify`
3. **Create Banking Link**: `POST /api/v1/applications/{applicationId}/banking/link-token`
4. **Get Application**: `GET /api/v1/applications/{applicationId}`

## Implementation Notes

- The application is created in memory (no database persistence yet)
- Application ID is generated client-side compatible format
- User ID is extracted from the JWT token (`req.userId`)
- Application status defaults to `pending`

## Future Enhancements

- Add database persistence for applications
- Add application listing endpoint (`GET /api/v1/applications`)
- Add application update endpoint (`PUT /api/v1/applications/:applicationId`)
- Add application deletion endpoint (`DELETE /api/v1/applications/:applicationId`)
