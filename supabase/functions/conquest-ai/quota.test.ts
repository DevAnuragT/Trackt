import assert from "node:assert/strict";
import { PGlite } from "npm:@electric-sql/pglite@0.3.14";

Deno.test("real PostgreSQL quota enforces UTC dates, exact caps and service-only access", async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create role anon;
      create role authenticated;
      create role service_role;
      create schema auth;
      create table auth.users (id uuid primary key);
    `);
    await db.exec(await Deno.readTextFile(
      new URL("../../migrations/20261012175500_trackt_ai_quota.sql", import.meta.url),
    ));

    const privileges = await db.query<{
      anon_can_spend: boolean;
      user_can_spend: boolean;
      service_can_spend: boolean;
      rls_enabled: boolean;
    }>(`
      select
        has_function_privilege('anon', 'public.consume_trackt_ai_request(uuid)', 'execute') as anon_can_spend,
        has_function_privilege('authenticated', 'public.consume_trackt_ai_request(uuid)', 'execute') as user_can_spend,
        has_function_privilege('service_role', 'public.consume_trackt_ai_request(uuid)', 'execute') as service_can_spend,
        relrowsecurity as rls_enabled
      from pg_class where oid = 'public.trackt_ai_usage'::regclass
    `);
    assert.deepEqual(privileges.rows[0], {
      anon_can_spend: false,
      user_can_spend: false,
      service_can_spend: true,
      rls_enabled: true,
    });

    const userIds = Array.from({ length: 6 }, (_, index) =>
      `00000000-0000-0000-0000-${String(index + 1).padStart(12, "0")}`);
    for (const id of userIds) {
      await db.query("insert into auth.users(id) values ($1)", [id]);
    }
    await db.exec("set timezone = 'Pacific/Kiritimati'");
    const consume = async (id: string) => {
      const result = await db.query<{ allowed: boolean }>(
        "select public.consume_trackt_ai_request($1) as allowed",
        [id],
      );
      return result.rows[0].allowed;
    };
    for (let attempt = 0; attempt < 20; attempt++) {
      assert.equal(await consume(userIds[0]), true);
    }
    assert.equal(await consume(userIds[0]), false, "21st per-user attempt must fail");
    const date = await db.query<{ correct_date: boolean }>(`
      select usage_date = (now() at time zone 'UTC')::date as correct_date
      from public.trackt_ai_usage limit 1
    `);
    assert.equal(date.rows[0].correct_date, true);

    for (const id of userIds.slice(1, 5)) {
      for (let attempt = 0; attempt < 20; attempt++) {
        assert.equal(await consume(id), true);
      }
    }
    assert.equal(await consume(userIds[5]), false, "101st global attempt must fail");
    const total = await db.query<{ total: string }>(
      "select sum(requests)::text as total from public.trackt_ai_usage",
    );
    assert.equal(total.rows[0].total, "100", "Denied requests must not increment usage");

    await db.exec("set role authenticated");
    await assert.rejects(
      () => db.query("select public.consume_trackt_ai_request($1)", [userIds[0]]),
      /permission denied/,
    );
    await assert.rejects(
      () => db.query("delete from public.trackt_ai_usage"),
      /permission denied/,
    );
    await db.exec("reset role");
  } finally {
    await db.close();
  }
});
