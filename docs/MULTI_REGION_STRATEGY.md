# Multi-Region Frontend Strategy

## Recommendation: Single Frontend with Region Routing

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Single Lovable Frontend                                │
│  app.credovo.com                                        │
│                                                         │
│  Routes:                                                │
│  - app.credovo.com/uk/*  → UK Backend                  │
│  - app.credovo.com/ae/*  → UAE Backend                 │
│  - app.credovo.com/us/*  → US Backend                   │
│  - app.credovo.com/eu/*  → EU Backend                   │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────┴───────────────┐
        │                               │
┌───────▼────────┐            ┌─────────▼────────┐
│ UK Backend    │            │ UAE Backend      │
│ (credovo-uk-  │            │ (credovo-uae-    │
│  apps-nonprod)│            │  apps-nonprod)   │
└───────────────┘            └──────────────────┘
```

## Why Single Frontend?

### ✅ Advantages

1. **Single Codebase**
   - One codebase to maintain
   - Shared components and logic
   - Easier updates and bug fixes
   - Consistent UX across regions

2. **Easier Development**
   - Single deployment pipeline
   - Shared feature flags
   - Unified testing
   - One Lovable project to manage

3. **Cost Effective**
   - One frontend deployment
   - Shared CDN and hosting
   - Lower maintenance overhead

4. **Region Detection**
   - Auto-detect user location
   - Route to appropriate backend
   - Fallback to default region

5. **Flexible Routing**
   - URL-based: `/uk/`, `/ae/`, `/us/`
   - Or subdomain: `uk.app.credovo.com`
   - Or geolocation-based routing

### ⚠️ Considerations

1. **Regional Customization**
   - Use feature flags for region-specific features
   - Conditional rendering based on region
   - Localization (i18n) for different languages

2. **Compliance**
   - Data residency handled by backend (already regional)
   - Frontend just routes to correct backend
   - Backend ensures data stays in region

3. **Performance**
   - Lovable uses CDN (global distribution)
   - Backend calls go to regional backend (low latency)
   - Good user experience

## Implementation

### Option 1: URL-Based Routing (Recommended)

```typescript
// Frontend routing
app.credovo.com/uk/apply     → UK Backend
app.credovo.com/ae/apply     → UAE Backend
app.credovo.com/us/apply     → US Backend

// Backend API URLs per region
const REGION_CONFIG = {
  uk: { apiUrl: 'https://orchestration-service-uk.run.app' },
  ae: { apiUrl: 'https://orchestration-service-uae.run.app' },
  us: { apiUrl: 'https://orchestration-service-us.run.app' },
  eu: { apiUrl: 'https://orchestration-service-eu.run.app' }
};

// Detect region from URL
const region = window.location.pathname.split('/')[1]; // 'uk', 'ae', etc.
const apiUrl = REGION_CONFIG[region]?.apiUrl || REGION_CONFIG.uk.apiUrl;
```

### Option 2: Geolocation-Based Routing

```typescript
// Auto-detect user location
const userRegion = detectUserRegion(); // Based on IP, browser locale, etc.
const apiUrl = REGION_CONFIG[userRegion]?.apiUrl || REGION_CONFIG.uk.apiUrl;
```

### Option 3: Subdomain Routing

```
uk.app.credovo.com  → UK Backend
ae.app.credovo.com  → UAE Backend
us.app.credovo.com  → US Backend
```

## Backend Architecture (Already Regional)

Your backend is already set up for regional deployment:

- **UK**: `credovo-uk-apps-nonprod`, `credovo-uk-apps-prod`
- **UAE**: `credovo-uae-apps-nonprod`, `credovo-uae-apps-prod`
- **US**: `credovo-us-apps-nonprod`, `credovo-us-apps-prod`
- **EU**: `credovo-eu-apps-nonprod`, `credovo-eu-apps-prod`

Each region has:
- Separate GCP project
- Regional data storage (GDPR compliance)
- Regional Cloud Run services
- Regional secrets

## Frontend Configuration

### Environment Variables (Lovable)

```bash
# Base configuration
REACT_APP_DEFAULT_REGION=uk

# Regional API URLs (optional - can be hardcoded in frontend)
REACT_APP_API_URL_UK=https://orchestration-service-uk.run.app
REACT_APP_API_URL_AE=https://orchestration-service-uae.run.app
REACT_APP_API_URL_US=https://orchestration-service-us.run.app
REACT_APP_API_URL_EU=https://orchestration-service-eu.run.app
```

### Frontend Code Example

```typescript
// utils/regionConfig.ts
export const REGION_CONFIG = {
  uk: {
    apiUrl: process.env.REACT_APP_API_URL_UK || 'https://orchestration-service-uk.run.app',
    locale: 'en-GB',
    currency: 'GBP'
  },
  ae: {
    apiUrl: process.env.REACT_APP_API_URL_AE || 'https://orchestration-service-uae.run.app',
    locale: 'en-AE',
    currency: 'AED'
  },
  us: {
    apiUrl: process.env.REACT_APP_API_URL_US || 'https://orchestration-service-us.run.app',
    locale: 'en-US',
    currency: 'USD'
  },
  eu: {
    apiUrl: process.env.REACT_APP_API_URL_EU || 'https://orchestration-service-eu.run.app',
    locale: 'en-GB',
    currency: 'EUR'
  }
};

// Detect region from URL path
export function getRegionFromPath(): string {
  const path = window.location.pathname;
  const region = path.split('/')[1];
  return REGION_CONFIG[region] ? region : 'uk'; // Default to UK
}

// Get API URL for current region
export function getApiUrl(): string {
  const region = getRegionFromPath();
  return REGION_CONFIG[region].apiUrl;
}

// Usage in components
const apiUrl = getApiUrl();
fetch(`${apiUrl}/api/v1/applications/123/kyc/initiate`, {
  headers: { 'Authorization': `Bearer ${token}` }
});
```

## Alternative: Separate Frontends (Not Recommended)

If you need completely separate frontends:

### Pros
- Complete isolation per region
- Independent deployments
- Region-specific customizations easier

### Cons
- Multiple codebases to maintain
- Code duplication
- More complex CI/CD
- Higher costs
- Harder to share features

## Recommendation Summary

**Use: Single Lovable Frontend with Region Routing**

1. **Start with one region** (UK recommended - `credovo-uk-apps-nonprod`)
2. **Implement region routing** in frontend
3. **Deploy to other regions** as needed
4. **Use feature flags** for region-specific features

This gives you:
- ✅ Single codebase
- ✅ Regional backend (data residency)
- ✅ Easy expansion to new regions
- ✅ Consistent UX
- ✅ Lower maintenance

## Next Steps

1. Choose starting region (UK recommended)
2. Update `terraform.tfvars` with correct project ID
3. Deploy backend to that region
4. Configure frontend with region routing
5. Expand to other regions as needed

