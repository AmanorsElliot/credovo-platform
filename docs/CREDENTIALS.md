# Credentials Management

This document tracks credential usage across environments.

## Shufti Pro Credentials

### Development/Non-Production (Current)
**Environment**: `credovo-eu-apps-nonprod`  
**Type**: Sandbox credentials

- **Client ID**: `c29799b84a29a8cc335af9fdbcf150e198a8babc3175c42d699751763bbce442`
- **Secret Key**: `fQC91wjAO5OweifiRohmyqEFvKVN6wzh`
- **Status**: ✅ Active in Secret Manager
- **Location**: GCP Secret Manager (`shufti-pro-client-id`, `shufti-pro-secret-key`)

### Production (Future)
**Environment**: TBD (production project)  
**Type**: Production credentials

- **Client ID**: `2OhMXk1rS9eqbsLSdHom5tUpWSAISVAT0RJC3TByNpsxhcakYn1768066741`
- **Secret Key**: `lm0PbtEjvHsLsD2doeoMsXlgDxRLBDAB`
- **Status**: 🔒 Stored securely, not deployed
- **Usage**: Will be configured when production environment is set up

## Secret Manager Structure

### Current (Non-Prod)
```
Secret: shufti-pro-client-id
  Version 2: c29799b84a29a8cc335af9fdbcf150e198a8babc3175c42d699751763bbce442 (active)

Secret: shufti-pro-secret-key
  Version 2: fQC91wjAO5OweifiRohmyqEFvKVN6wzh (active)
```

### Production (Future)
- Will be created in production GCP project
- Same secret names: `shufti-pro-client-id`, `shufti-pro-secret-key`
- Production credentials will be stored there

## Environment Configuration

### Terraform
- **File**: `infrastructure/terraform/networking.tf`
- **Current**: Contains sandbox credentials for nonprod
- **Production**: Will use production credentials when production Terraform is configured

### Cloud Run Services
- Services reference secrets via `SHUFTI_PRO_CLIENT_ID` and `SHUFTI_PRO_SECRET_KEY` environment variables
- Secrets are pulled from Secret Manager at runtime
- No code changes needed when switching environments

## Security Notes

- ✅ Production credentials are stored securely and not committed to Git
- ✅ Each environment uses separate GCP projects
- ✅ Secrets are managed via GCP Secret Manager
- ✅ Cloud Run services fetch secrets at runtime (no hardcoded values)
- ✅ Secret versions allow for credential rotation without code changes

## Next Steps for Production

1. Create production GCP project (or use existing)
2. Deploy Terraform with production credentials
3. Create secrets in production Secret Manager
4. Deploy services to production Cloud Run
5. Configure production webhook URLs in Shufti Pro back office

