// deno-lint-ignore-file no-explicit-any
import { config } from "./config.ts";

function b64url(buf: ArrayBuffer | Uint8Array) {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export async function signAccessToken(
  userId: string,
  email: string,
): Promise<string> {
  const header = { alg: "HS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    sub: userId,
    email,
    iat: now,
    exp: now + config.accessTtlSec,
  };
  const enc = new TextEncoder();
  const h = b64url(enc.encode(JSON.stringify(header)));
  const p = b64url(enc.encode(JSON.stringify(payload)));
  const data = `${h}.${p}`;
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(config.jwtSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(data));
  return `${data}.${b64url(sig)}`;
}

export async function verifyAccessToken(
  token: string,
): Promise<{ userId: string; email: string } | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  const [h, p, s] = parts;
  let header: any;
  try {
    header = JSON.parse(
      new TextDecoder().decode(
        Uint8Array.from(
          atob(
            h.replace(/-/g, "+").replace(/_/g, "/") +
              "===".slice(0, (4 - (h.length % 4)) % 4),
          ),
          (c) => c.charCodeAt(0),
        ),
      ),
    );
  } catch {
    return null;
  }
  if (header?.alg !== "HS256") return null;
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(config.jwtSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const sigBytes = Uint8Array.from(
    atob(
      s.replace(/-/g, "+").replace(/_/g, "/") +
        "===".slice(0, (4 - (s.length % 4)) % 4),
    ),
    (c) => c.charCodeAt(0),
  );
  const ok = await crypto.subtle.verify(
    "HMAC",
    key,
    sigBytes,
    enc.encode(`${h}.${p}`),
  );
  if (!ok) return null;
  try {
    const payload = JSON.parse(
      new TextDecoder().decode(
        Uint8Array.from(
          atob(
            p.replace(/-/g, "+").replace(/_/g, "/") +
              "===".slice(0, (4 - (p.length % 4)) % 4),
          ),
          (c) => c.charCodeAt(0),
        ),
      ),
    );
    if (
      typeof payload.exp !== "number" ||
      payload.exp < Math.floor(Date.now() / 1000)
    ) return null;
    if (typeof payload.sub !== "string" || payload.sub === "") return null;
    if (typeof payload.email !== "string" || payload.email === "") return null;
    return { userId: payload.sub, email: payload.email };
  } catch {
    return null;
  }
}
