# Secure KIMI conquest recaps

`conquest-ai` runs on Supabase Edge Functions. It requires a real Supabase user
session, validates the run metrics, and calls KIMI with a server-side secret.
Anonymous judge demos keep working without AI; they never receive a fake
KIMI-generated message.

The database quota is shared by all function instances: 20 attempts per user
per UTC day, and 100 attempts per project per day. Failed provider attempts
still consume quota to limit repeated paid requests. Only `service_role` can
call the quota function; the mobile app cannot reset usage.

## Deploy

Authenticate with `supabase login`. In the existing project, add
`KIMI_API_KEY` under **Edge Functions > Secrets**. The default model is
`kimi-k2.6`, which supports disabling thinking for a short, fast recap.
Do not switch to a model without checking its supported parameters.
The KIMI account also needs available API credits. A valid key can list models
while paid completions still fail with HTTP 429 for insufficient balance.

Apply only the new isolated quota migration, then deploy only this function:

```sh
supabase db query --linked --project-ref YOUR_PROJECT_REF \
  --file supabase/migrations/20261012175500_trackt_ai_quota.sql
supabase functions deploy conquest-ai --project-ref YOUR_PROJECT_REF --use-api
```

Do not use `db reset`, replace existing database migrations, or disable JWT
verification. The function additionally verifies the caller with Supabase Auth.
The app derives the function URL from its existing Supabase project URL.

If the CLI reports a `cli_login_postgres` role error, open the existing
project's **SQL Editor** and run the contents of the quota migration there.
Do not change role permissions or reset the database to work around this.
Until the migration is applied, authenticated requests fail closed with HTTP
503 and cannot spend KIMI credits.

## Tests

```sh
node --experimental-strip-types --test supabase/functions/conquest-ai/handler.test.ts
npx --yes deno test --allow-read --allow-env --allow-sys \
  supabase/functions/conquest-ai/quota.test.ts
```

The quota test runs the actual SQL migration in PostgreSQL WASM, without a
Docker daemon or hosted database. It verifies the exact 20/100 daily caps,
UTC dates, RLS, and service-only privileges. Test dependencies are pinned and
are not included in the deployed function.

Never put KIMI credentials, Supabase access tokens or service-role keys in
Flutter assets. `SUPABASE_ANON_KEY` is a public client key, not deployment
authorization.
