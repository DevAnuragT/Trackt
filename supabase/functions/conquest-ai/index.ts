import { createClient } from "npm:@supabase/supabase-js@2.99.2";
import { createHandler } from "./handler.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const auth = createClient(supabaseUrl, supabaseAnonKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const admin = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

Deno.serve(createHandler({
  apiKey: Deno.env.get("KIMI_API_KEY") ?? "",
  model: Deno.env.get("KIMI_MODEL") ?? "kimi-k2.6",
  fetch,
  authenticate: async (token) => {
    const { data, error } = await auth.auth.getUser(token);
    if (error) {
      if (error.status && error.status >= 500) throw error;
      return null;
    }
    return data.user?.id ?? null;
  },
  consumeQuota: async (userId) => {
    const { data, error } = await admin.rpc("consume_trackt_ai_request", {
      p_user_id: userId,
    });
    if (error) throw error;
    if (typeof data !== "boolean") throw new Error("Invalid quota response");
    return data;
  },
}));
