// Supabase Edge Function: supabase/functions/search/index.ts
// This function handles company search requests

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-token',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Extract Supabase JWT token from Authorization header
    const authHeader = req.headers.get("Authorization");
    
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid authorization header" }),
        { 
          status: 401, 
          headers: { ...corsHeaders, "Content-Type": "application/json" } 
        }
      );
    }

    const supabaseToken = authHeader.substring(7);

    // HYBRID APPROACH: API Gateway has a bug with GET requests
    // GET requests: Call proxy service directly (bypass API Gateway)
    // POST/PUT/DELETE: Use API Gateway
    
    const apiGatewayUrl = Deno.env.get("API_GATEWAY_URL") || 
      "https://proxy-gateway-ayd13s2s.ew.gateway.dev";
    const proxyServiceUrl = Deno.env.get("PROXY_SERVICE_URL") || 
      "https://proxy-service-saz24fo3sa-ew.a.run.app";

    // Extract query parameters from request URL
    const url = new URL(req.url);
    const queryString = url.search; // Includes "?" if present, empty string if not
    const path = url.pathname; // e.g., "/api/v1/companies/search"
    
    console.log(`[Edge Function] Method: ${req.method}`);
    console.log(`[Edge Function] Path: ${path}`);
    console.log(`[Edge Function] Query string: ${queryString}`);

    // For GET requests, call proxy service directly (API Gateway bug workaround)
    if (req.method === "GET") {
      const targetUrl = `${proxyServiceUrl}${path}${queryString}`;
      console.log(`[Edge Function] GET request - calling proxy directly: ${targetUrl}`);
      console.log(`[Edge Function] Workaround: Bypassing API Gateway due to GET request bug`);
      
      const backendResponse = await fetch(targetUrl, {
        method: "GET",
        headers: {
          // Proxy service expects Authorization header with Supabase JWT
          "Authorization": `Bearer ${supabaseToken}`,
          // Also send in custom header for consistency
          "X-Supabase-Token": supabaseToken,
        },
        // No body for GET requests
      });

      console.log(`[Edge Function] API Gateway response status: ${backendResponse.status}`);
      console.log(`[Edge Function] API Gateway response headers:`, Object.fromEntries(backendResponse.headers.entries()));

      if (!backendResponse.ok) {
        const errorText = await backendResponse.text();
        console.error(`[Edge Function] API Gateway error (${backendResponse.status}): ${errorText.substring(0, 500)}`);
        
        return new Response(
          JSON.stringify({ 
            error: "Backend request failed",
            status: backendResponse.status,
            message: errorText
          }),
          { 
            status: backendResponse.status,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
          }
        );
      }

      const data = await backendResponse.json();
      console.log(`[Edge Function] Success: Received ${data.companies?.length || 0} companies`);

      return new Response(
        JSON.stringify(data),
        {
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    } else {
      // POST, PUT, DELETE - Use API Gateway (these work fine)
      const targetUrl = `${apiGatewayUrl}${path}`;
      console.log(`[Edge Function] ${req.method} request - calling API Gateway: ${targetUrl}`);
      
      const body = await req.json();
      
      const backendResponse = await fetch(targetUrl, {
        method: req.method,
        headers: {
          "X-Supabase-Token": supabaseToken,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });

      if (!backendResponse.ok) {
        const errorText = await backendResponse.text();
        return new Response(
          JSON.stringify({ 
            error: "Backend request failed",
            status: backendResponse.status,
            message: errorText
          }),
          { 
            status: backendResponse.status,
            headers: { ...corsHeaders, "Content-Type": "application/json" }
          }
        );
      }

      const data = await backendResponse.json();
      return new Response(
        JSON.stringify(data),
        {
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }
  } catch (error: any) {
    console.error("[Edge Function] Error:", error);
    return new Response(
      JSON.stringify({ 
        error: "Internal Server Error",
        message: error.message 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  }
});
