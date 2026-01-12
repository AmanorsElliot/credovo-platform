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

    // Get API Gateway URL from environment
    const apiGatewayUrl = Deno.env.get("API_GATEWAY_URL") || 
      "https://proxy-gateway-ayd13s2s.ew.gateway.dev";

    // Extract query parameters from request URL
    const url = new URL(req.url);
    const queryString = url.search; // Includes "?" if present, empty string if not
    
    // Build target URL: API Gateway + path + query string
    // For search function, the path should be /api/v1/companies/search
    const targetPath = "/api/v1/companies/search";
    const targetUrl = `${apiGatewayUrl}${targetPath}${queryString}`;

    console.log(`[Edge Function] Method: ${req.method}`);
    console.log(`[Edge Function] Calling API Gateway: ${targetUrl}`);
    console.log(`[Edge Function] Query string: ${queryString}`);
    console.log(`[Edge Function] Headers: X-Supabase-Token only (no Content-Type, no Authorization)`);

    // For GET requests, call API Gateway with proper format
    if (req.method === "GET") {
      const backendResponse = await fetch(targetUrl, {
        method: "GET",
        headers: {
          // CRITICAL: Only X-Supabase-Token header
          // DO NOT include Content-Type (GET requests don't have bodies)
          // DO NOT include Authorization (API Gateway adds it automatically)
          "X-Supabase-Token": supabaseToken,
        },
        // CRITICAL: No body for GET requests
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
      // POST, PUT, DELETE - include Content-Type and body
      const body = await req.json();
      
      const backendResponse = await fetch(`${apiGatewayUrl}${targetPath}`, {
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
