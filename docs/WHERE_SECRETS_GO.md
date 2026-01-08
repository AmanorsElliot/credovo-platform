# Where Secrets Need to Be Stored

## Location: GCP Secret Manager

All secrets are stored in **Google Cloud Secret Manager** in your GCP project: `credovo-platform-dev`

## Secret Storage Flow

```
┌─────────────────────────────────────────────────────────┐
│  GCP Secret Manager (credovo-platform-dev)             │
│                                                         │
│  Secret Name: supabase-url                             │
│  Secret Value: https://jywjbinndnanxscxqdes.supabase.co│
│  Location: projects/credovo-platform-dev/secrets/      │
│            supabase-url                                 │
└─────────────────────────────────────────────────────────┘
                        │
                        │ Referenced by
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Terraform Configuration                                │
│  (infrastructure/terraform/networking.tf)               │
│                                                         │
│  Creates secret placeholder                             │
│  Secret ID: "supabase-url"                             │
└─────────────────────────────────────────────────────────┘
                        │
                        │ Injected as
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Cloud Run Service (orchestration-service)              │
│                                                         │
│  Environment Variable: SUPABASE_URL                    │
│  Source: Secret Manager → supabase-url                 │
│  Access: process.env.SUPABASE_URL                      │
└─────────────────────────────────────────────────────────┘
```

## Step-by-Step: Where to Put the Secret

### 1. **GCP Secret Manager** (Final Destination)

**Location**: 
- **Project**: `credovo-eu-apps-nonprod`
- **Secret Name**: `supabase-url`
- **Full Path**: `projects/credovo-eu-apps-nonprod/secrets/supabase-url`

**How to Add**:
```powershell
# This command stores it in GCP Secret Manager
echo -n "https://jywjbinndnanxscxqdes.supabase.co" | gcloud secrets versions add supabase-url --data-file=-
```

### 2. **Terraform** (Creates the Secret Container)

**File**: `infrastructure/terraform/networking.tf`

**What it does**:
- Creates the secret "container" in Secret Manager
- Sets up placeholder value
- You need to update the actual value using `gcloud` command above

**Already configured**: ✅ The Terraform code already creates the `supabase-url` secret

### 3. **Cloud Run Service** (Uses the Secret)

**File**: `infrastructure/terraform/cloud-run.tf`

**What it does**:
- References the secret from Secret Manager
- Injects it as environment variable `SUPABASE_URL`
- Your code accesses it via `process.env.SUPABASE_URL`

**Already configured**: ✅ The Cloud Run service is already set up to use the secret

## Visual Location

```
GCP Console
├── credovo-eu-apps-nonprod (Project)
    └── Secret Manager
        └── supabase-url (Secret)
            └── Versions
                └── latest (Current Value)
                    └── "https://jywjbinndnanxscxqdes.supabase.co"
```

## How to Access in GCP Console

1. Go to: https://console.cloud.google.com/security/secret-manager
2. Select project: `credovo-eu-apps-nonprod`
3. Find secret: `supabase-url`
4. View/Edit the secret value

## How Your Code Accesses It

```typescript
// In your backend code (orchestration-service)
const supabaseUrl = process.env.SUPABASE_URL;
// Value: "https://jywjbinndnanxscxqdes.supabase.co"

// The code automatically constructs JWKS endpoint:
const jwksUri = `${supabaseUrl}/auth/v1/.well-known/jwks.json`;
// Result: "https://jywjbinndnanxscxqdes.supabase.co/auth/v1/.well-known/jwks.json"
```

## Summary

**The secret needs to be in**: 
- ✅ **GCP Secret Manager** 
- ✅ Project: `credovo-eu-apps-nonprod`
- ✅ Secret name: `supabase-url`

**How to put it there**:
```powershell
echo -n "https://jywjbinndnanxscxqdes.supabase.co" | gcloud secrets versions add supabase-url --data-file=-
```

**Terraform and Cloud Run are already configured** - you just need to add the actual value to Secret Manager!

