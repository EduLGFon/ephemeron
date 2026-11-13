import { assertEquals } from "@std/assert";
import { PostgresStorage } from "../src/pg_storage.ts";

const hasDb = !!Deno.env.get("DATABASE_URL");

Deno.test({
  name: "pg storage basic roundtrip",
  ignore: !hasDb,
  async fn() {
    const s = new PostgresStorage();
    const u = await s.createUser("pg@test.com", "hash");
    const found = await s.findUserByEmail("PG@Test.com");
    assertEquals(found?.id, u.id);
    await s.deleteUser(u.id);
  },
});
