# API Gateway GET Fix Attempts

## Attempts Made

### Attempt 1: Remove Path Parameter from Wildcard
**What we did**: Removed the `parameters` block declaring `path` from `/{path=**}`
**Result**: ❌ Deployment failed - "undefined field 'path' on message"

### Attempt 2: Wildcard GET Only (No Path Parameter)
**What we did**: Added wildcard `/{path=**}` with GET operation only, no path parameter
**Result**: ❌ Deployment failed - "undefined field 'path' on message 'google.protobuf.Empty'"

### Attempt 3: Explicit Routes Only
**What we did**: Removed wildcard entirely, using only explicit routes:
- `/api/v1/health` (GET)
- `/api/v1/companies/search` (GET)
- `/api/v1/applications` (GET, POST, PUT, DELETE)

**Result**: ✅ Deployment succeeded, but GET requests still return 400

## Current Status

- ✅ **Deployment**: Successful with explicit routes only
- ✅ **POST requests**: Working (return 401, which is expected)
- ❌ **GET requests**: Still returning 400 (but different error - not Google HTML)

## Observations

1. **Error changed**: The 400 error is no longer the Google HTML error page
2. **Empty response**: The error response body is empty
3. **POST works**: This confirms the gateway is functional
4. **Explicit routes deployed**: The spec was successfully deployed

## Possible Next Steps

1. **Check API Gateway logs** for specific error messages
2. **Verify deployed spec** matches what we think we deployed
3. **Test with authentication** to see if that changes behavior
4. **Check if there's a different issue** with GET request handling

## Diagnosis Status

The original diagnosis (wildcard + path parameter) was correct for the deployment error, but:
- Removing the path parameter caused "undefined field 'path'" errors
- Using explicit routes only still results in GET 400 errors

This suggests there may be **another issue** beyond the wildcard/path parameter problem.
