# API Gateway GET Fix Status

## Fix Applied

✅ **Removed wildcard route** `/{path=**}` entirely
✅ **Removed duplicate path parameter** declaration
✅ **Using explicit routes only** (Google's recommended pattern)
✅ **Deployed updated configuration** successfully

## Current Status

- ✅ **POST requests**: Working (return 401 without auth, which is expected)
- ❌ **GET requests**: Still returning 400 errors
- ✅ **API Gateway deployment**: Successful
- ✅ **Configuration updated**: New spec deployed

## What We Changed

### Before
```yaml
/{path=**}:
  parameters:
    - name: path
      in: path
      required: true
      type: string
  post:
    # ...
```

### After
```yaml
# Removed wildcard entirely
# Using explicit routes only:
/api/v1/health:
  get:
    # ...
/api/v1/companies/search:
  get:
    # ...
/api/v1/applications:
  get:
    # ...
  post:
    # ...
  put:
    # ...
  delete:
    # ...
```

## Possible Reasons for Continued 400

1. **Propagation Delay**: API Gateway changes can take 2-5 minutes to fully propagate
2. **Caching**: Browser or intermediate caches may be serving old responses
3. **Another Spec Issue**: There may be another configuration issue we haven't identified
4. **Diagnosis Refinement**: The root cause may be slightly different than initially diagnosed

## Next Steps

1. **Wait 5 minutes** and test again (propagation delay)
2. **Check API Gateway logs** for specific error messages:
   ```powershell
   gcloud logging read "resource.type=api_gateway AND resource.labels.gateway_id=proxy-gateway" --limit=20 --project=credovo-eu-apps-nonprod
   ```
3. **Verify deployed spec** matches what we think:
   ```powershell
   gcloud api-gateway api-configs describe proxy-api-config --api=proxy-api --project=credovo-eu-apps-nonprod --format="yaml"
   ```
4. **Test with authentication** to see if that changes the behavior

## Verification

After waiting, test:
```powershell
# Should return 200 or 401 (not 400)
Invoke-WebRequest -Uri "https://proxy-gateway-ayd13s2s.ew.gateway.dev/api/v1/health" -Method GET
```

If still 400 after 5 minutes, we may need to investigate further.
