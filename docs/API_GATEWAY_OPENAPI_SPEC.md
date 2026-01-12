# API Gateway OpenAPI Specification

## Current Structure

The API Gateway OpenAPI spec uses a hybrid approach:

1. **Explicit endpoints** for commonly used routes (like company search)
2. **Catch-all pattern** (`/{path=**}`) for all other endpoints

## Company Search Endpoint

The company search endpoint is explicitly defined:

```yaml
/api/v1/companies/search:
  get:
    summary: Search companies
    operationId: searchCompanies
    parameters:
      - in: header
        name: Authorization
        type: string
        required: true
      - in: header
        name: X-Supabase-Token
        type: string
        required: true
      - name: query
        in: query
        required: true
        schema:
          type: string
      - name: limit
        in: query
        required: false
        schema:
          type: integer
          default: 10
    x-google-backend:
      address: ${proxy_service_url}
      path_translation: APPEND_PATH_TO_ADDRESS
      protocol: h2
      jwt_audience: ${proxy_service_url}
```

## Important Notes

### Path Translation

When using `path_translation: APPEND_PATH_TO_ADDRESS`:
- The `address` should be the **base URL** of the proxy service (no path)
- API Gateway will append the full request path to the address
- Example: Request to `/api/v1/companies/search?query=test` → `${proxy_service_url}/api/v1/companies/search?query=test`

### Why Not Use Full Path in Address?

If you set `address: ${proxy_service_url}/api/v1/companies/search` with `APPEND_PATH_TO_ADDRESS`:
- Request to `/api/v1/companies/search` → `${proxy_service_url}/api/v1/companies/search/api/v1/companies/search` ❌ (double path)

### Alternative: CONSTANT_ADDRESS

If you want to use a specific path in the address, use `path_translation: CONSTANT_ADDRESS`:
```yaml
x-google-backend:
  address: ${proxy_service_url}/api/v1/companies/search
  path_translation: CONSTANT_ADDRESS  # Don't append path
```

But this only works for that specific endpoint and doesn't handle query parameters well.

## Catch-All Pattern

The `/{path=**}` pattern handles all other endpoints:
- `/api/v1/applications/*`
- `/api/v1/banking/*`
- `/health`
- etc.

This ensures all endpoints work without explicitly defining each one.

## Updating the Spec

After updating `infrastructure/terraform/api-gateway-openapi.yaml`, redeploy:

```powershell
cd scripts
.\deploy-api-gateway.ps1
```

This will:
1. Delete the existing gateway and config
2. Recreate them with the new OpenAPI spec
3. Grant necessary IAM permissions
