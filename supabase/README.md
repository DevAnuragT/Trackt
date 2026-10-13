# Supabase schema history

Trackt continues to use its existing Supabase authentication, profiles and
spatial database. These services are independent of the removed AI recap.

The deployed `conquest-ai` Edge Function and its KIMI server secrets have been
retired. There are no AI handlers, client calls or recap widgets in the app.

The previously applied `20261012175500_trackt_ai_quota.sql` migration is
retained as database history, not an active feature or a deployment step.
Its isolated quota table and service-role-only function remain inert in the
existing database; no app or Edge Function calls them. Removal of the AI
integration does not reset the database, alter roles, or delete usage history.

Never package Supabase deployment/service-role credentials in Flutter assets.
`SUPABASE_ANON_KEY` is a public client key, not deployment authorization.
