// Admin-only: creates a new app user with an auto-generated temporary
// password. This is the one place the service_role key is used — it only
// ever lives in this function's auto-injected environment, never in the
// browser. The caller's own JWT (forwarded by the client via the
// Authorization header) is independently verified below before any
// privileged work happens; Supabase's edge runtime also rejects requests
// with no valid JWT at all before this code even runs (verify_jwt: true).
import { createClient } from 'npm:@supabase/supabase-js@2.110.7';

function generateTempPassword(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  const bytes = new Uint8Array(14);
  crypto.getRandomValues(bytes);
  let out = '';
  for (const b of bytes) out += chars[b % chars.length];
  return out;
}

Deno.serve(async (req: Request) => {
  const cors = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

  try {
    const authHeader = req.headers.get('Authorization') || '';
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
    const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Verify who's actually calling, using their own forwarded token —
    // never trust a plain user id passed in the request body. is_admin()
    // is the same Postgres function the database's RLS policies use, so
    // there's exactly one place that defines who the admin is.
    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: callerData, error: callerErr } = await callerClient.auth.getUser();
    if (callerErr || !callerData?.user) return json({ error: 'Not signed in' }, 401);
    const { data: isAdminResult, error: isAdminErr } = await callerClient.rpc('is_admin');
    if (isAdminErr || !isAdminResult) return json({ error: 'Forbidden — admin only' }, 403);

    const body = await req.json().catch(() => ({}));
    const email = String(body.email || '').trim();
    if (!email) return json({ error: 'Email is required' }, 400);
    const profile = body.profile || {};

    const tempPassword = generateTempPassword();
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password: tempPassword,
      email_confirm: true,
      user_metadata: { must_change_password: true },
    });
    if (createErr) return json({ error: createErr.message }, 400);

    const { error: profileErr } = await admin.from('profile').insert({
      user_id: created.user.id,
      name: String(profile.name || ''),
      code: String(profile.code || ''),
      grade: String(profile.grade || ''),
      location: String(profile.location || ''),
      project: String(profile.project || ''),
      address: String(profile.address || ''),
      custom_modes: [],
    });
    if (profileErr) console.error('profile seed failed', profileErr);

    return json({ id: created.user.id, email, tempPassword });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
