# Lovable Frontend Development Prompt

Copy and paste this prompt into Lovable to start building the Credovo mortgage lending platform frontend:

---

## Project Overview

Build a modern, responsive web application for **Credovo**, a digital mortgage lending platform that enables applicants to complete a full mortgage agreement in under 24 hours. The application should connect to the existing backend API and provide a seamless user experience for mortgage applications.

## Backend API Configuration

**API Base URL**: `https://orchestration-service-saz24fo3sa-ew.a.run.app`

**Environment Variable**: Set `REACT_APP_API_URL` to the base URL above.

## Authentication

The backend supports two authentication methods:

### Option 1: Supabase Authentication (Recommended)
- If using Supabase, configure `REACT_APP_SUPABASE_URL` and `REACT_APP_SUPABASE_ANON_KEY`
- Backend validates Supabase JWT tokens directly
- Send token in `Authorization: Bearer <token>` header

### Option 2: Token Exchange
- Exchange user info for backend JWT: `POST /api/v1/auth/token`
- Request body: `{ userId: string, email?: string, name?: string }`
- Response: `{ token: string, expiresIn: number, user: {...} }`
- Store token and use for all API requests

## Core Features to Implement

### 1. Company Search & Autocomplete
- **Endpoint**: `GET /api/v1/companies/search?query={name}&limit={10}`
- **Authentication**: Required (Bearer token)
- **Feature**: Real-time company name autocomplete for business applications
- **UI**: Search input with dropdown results showing company names
- **Example Request**:
  ```typescript
  fetch(`${API_URL}/api/v1/companies/search?query=test&limit=10`, {
    headers: { 'Authorization': `Bearer ${token}` }
  })
  ```

### 2. KYC (Know Your Customer) Verification
- **Initiate**: `POST /api/v1/applications/{applicationId}/kyc/initiate`
- **Status**: `GET /api/v1/applications/{applicationId}/kyc/status`
- **Authentication**: Required
- **Feature**: Identity verification for individual applicants
- **Request Body**:
  ```json
  {
    "type": "individual",
    "data": {
      "firstName": "John",
      "lastName": "Doe",
      "dateOfBirth": "1990-01-01",
      "email": "john.doe@example.com",
      "country": "GB",
      "address": {
        "line1": "123 Test Street",
        "city": "London",
        "postcode": "SW1A 1AA",
        "country": "GB"
      }
    }
  }
  ```
- **UI**: Multi-step form with document upload, status tracking, and progress indicators

### 3. KYB (Know Your Business) Verification
- **Initiate**: `POST /api/v1/applications/{applicationId}/kyb/initiate`
- **Status**: `GET /api/v1/applications/{applicationId}/kyb/status`
- **Authentication**: Required
- **Feature**: Business verification for company applications
- **Request Body**:
  ```json
  {
    "companyNumber": "12345678",
    "companyName": "Test Company Ltd",
    "country": "GB",
    "email": "company@example.com"
  }
  ```
- **UI**: Business details form with company search integration

### 4. Open Banking Integration (Plaid)
- **Create Link Token**: `POST /api/v1/applications/{applicationId}/banking/link-token`
- **Exchange Token**: `POST /api/v1/applications/{applicationId}/banking/exchange-token`
- **Get Balances**: `POST /api/v1/applications/{applicationId}/banking/accounts/balance`
- **Get Transactions**: `POST /api/v1/applications/{applicationId}/banking/transactions`
- **Income Verification**: `POST /api/v1/applications/{applicationId}/banking/income/verify`
- **Authentication**: Required
- **Feature**: Connect bank accounts, view transactions, verify income
- **UI**: Plaid Link integration, account selection, transaction history, income verification dashboard

## Application Flow

### Step 1: Application Creation
- User creates a new mortgage application
- Generate unique `applicationId` (UUID or timestamp-based)
- Store application state locally or in state management

### Step 2: Company Search (for Business Applications)
- If business application, show company search field
- Real-time autocomplete as user types
- Display company results with selection

### Step 3: KYC/KYB Verification
- Show appropriate form (KYC for individuals, KYB for businesses)
- Collect required information
- Submit verification request
- Show status polling with progress indicators
- Display verification results when complete

### Step 4: Open Banking Connection
- Initiate Plaid Link flow
- User connects bank account
- Exchange public token
- Display account balances and transactions
- Run income verification

### Step 5: Application Review
- Show all collected information
- Display verification statuses
- Allow submission when all steps complete

## UI/UX Requirements

### Design
- **Modern, clean interface** with professional financial services aesthetic
- **Responsive design** for mobile, tablet, and desktop
- **Accessible** (WCAG 2.1 AA compliance)
- **Loading states** for all async operations
- **Error handling** with user-friendly messages
- **Progress indicators** for multi-step processes

### Key Pages/Components

1. **Dashboard/Home**
   - Application overview
   - Quick actions (start new application, view existing)
   - Status cards for active applications

2. **Application Form**
   - Multi-step wizard interface
   - Step 1: Application type (Individual/Business)
   - Step 2: Personal/Business details
   - Step 3: Company search (if business)
   - Step 4: KYC/KYB verification
   - Step 5: Banking connection
   - Step 6: Review and submit

3. **Company Search Component**
   - Autocomplete input field
   - Dropdown with search results
   - Loading states
   - Error handling

4. **Verification Status Component**
   - Real-time status updates
   - Progress indicators
   - Success/error states
   - Document upload interface (if needed)

5. **Banking Dashboard**
   - Connected accounts list
   - Account balances
   - Transaction history
   - Income verification status

## Technical Requirements

### State Management
- Use React Context, Redux, or Zustand for application state
- Store authentication token securely
- Cache API responses where appropriate

### Error Handling
- Global error boundary
- API error handling with user-friendly messages
- Retry logic for failed requests
- Network error handling

### API Client
- Create a centralized API client with:
  - Automatic token injection
  - Request/response interceptors
  - Error handling
  - TypeScript types for all endpoints

### TypeScript
- Define interfaces for all API requests/responses
- Type-safe API calls
- Type-safe form handling

## Example API Client Structure

```typescript
// api/client.ts
const API_URL = process.env.REACT_APP_API_URL;

class ApiClient {
  private getAuthHeaders() {
    const token = localStorage.getItem('authToken');
    return {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    };
  }

  async searchCompanies(query: string, limit = 10) {
    const response = await fetch(
      `${API_URL}/api/v1/companies/search?query=${encodeURIComponent(query)}&limit=${limit}`,
      { headers: this.getAuthHeaders() }
    );
    if (!response.ok) throw new Error('Company search failed');
    return response.json();
  }

  async initiateKYC(applicationId: string, data: KYCRequest) {
    const response = await fetch(
      `${API_URL}/api/v1/applications/${applicationId}/kyc/initiate`,
      {
        method: 'POST',
        headers: this.getAuthHeaders(),
        body: JSON.stringify(data)
      }
    );
    if (!response.ok) throw new Error('KYC initiation failed');
    return response.json();
  }

  async getKYCStatus(applicationId: string) {
    const response = await fetch(
      `${API_URL}/api/v1/applications/${applicationId}/kyc/status`,
      { headers: this.getAuthHeaders() }
    );
    if (!response.ok) throw new Error('Status check failed');
    return response.json();
  }

  // Add more methods for other endpoints...
}
```

## Testing Endpoints

### Health Check
```typescript
fetch(`${API_URL}/health`)
  .then(res => res.json())
  .then(data => console.log('Backend health:', data));
```

### Authentication Test
```typescript
// Token exchange
fetch(`${API_URL}/api/v1/auth/token`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    userId: 'test-user-123',
    email: 'test@example.com'
  })
})
  .then(res => res.json())
  .then(data => {
    localStorage.setItem('authToken', data.token);
    console.log('Authenticated:', data);
  });
```

## Additional Notes

- **CORS**: Backend is configured to allow requests from `https://credovo-webapp.lovable.app`
- **Rate Limiting**: Be mindful of API rate limits
- **Error Codes**: Handle 401 (Unauthorized), 403 (Forbidden), 404 (Not Found), 500 (Server Error)
- **Loading States**: Show loading indicators for all API calls
- **Optimistic Updates**: Consider optimistic UI updates where appropriate
- **Form Validation**: Client-side validation before API calls
- **Accessibility**: Ensure keyboard navigation, screen reader support, proper ARIA labels

## Getting Started

1. Set up environment variables (`REACT_APP_API_URL`)
2. Implement authentication flow
3. Create API client with TypeScript types
4. Build company search component
5. Build KYC/KYB forms
6. Integrate Plaid Link for banking
7. Create application flow/wizard
8. Add status tracking and progress indicators
9. Implement error handling and loading states
10. Test all flows end-to-end

---

**Start by setting up the project structure, authentication, and API client, then build the core features one by one.**
