// Edge Function: groupsharing
// Purpose: Scan Firebase RTDB for stale heartbeats and send FCM data messages
// to restart the Android foreground service via PushMessagingService.
//
// Required Supabase secrets (set via `supabase secrets set ...`):
// - GOOGLE_SA_CLIENT_EMAIL
// - GOOGLE_SA_PRIVATE_KEY   (PKCS#8 PEM with newlines)
// - RTDB_URL                (e.g., https://<project>-default-rtdb.firebaseio.com)
// - GCP_PROJECT_ID          (Firebase project id)

const TOKEN_URL = "https://oauth2.googleapis.com/token";
const SCOPES = [
  "https://www.googleapis.com/auth/firebase.messaging",
  "https://www.googleapis.com/auth/firebase.database",
].join(" ");

function b64url(bytes: Uint8Array) {
  return btoa(String.fromCharCode(...bytes))
    .replace(/=+$/,"")
    .replace(/\+/g,"-")
    .replace(/\//g,"_");
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem
    .replaceAll("\r", "")
    .replaceAll("\n", "")
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .trim();
  const binStr = atob(b64);
  const bytes = new Uint8Array(binStr.length);
  for (let i = 0; i < binStr.length; i++) bytes[i] = binStr.charCodeAt(i);
  return bytes;
}

async function getAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claim = b64url(new TextEncoder().encode(JSON.stringify({
    iss: Deno.env.get("GOOGLE_SA_CLIENT_EMAIL"),
    scope: SCOPES,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  })));

  const pkcs8Pem = Deno.env.get("GOOGLE_SA_PRIVATE_KEY")!;
  const rawKey = pemToDer(pkcs8Pem);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    rawKey.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const toSign = new TextEncoder().encode(`${header}.${claim}`);
  const sigBuf = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, toSign);
  const sig = b64url(new Uint8Array(sigBuf));
  const assertion = `${header}.${claim}.${sig}`;

  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const json = await res.json();
  return json.access_token as string;
}

async function processStaleHeartbeats() {
  const accessToken = await getAccessToken();

  const rtdbUrl = Deno.env.get("RTDB_URL")!;
  const projectId = Deno.env.get("GCP_PROJECT_ID")!;
  const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  // Read users from RTDB
  const usersRes = await fetch(`${rtdbUrl}/users.json`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const users = await usersRes.json() as Record<string, any> | null;
  if (!users) return { sent: 0, message: "No users" };

  const now = Date.now();
  const cutoffMs = 3 * 60 * 1000; // 3 minutes
  let sent = 0;

  const sends = Object.entries(users).map(async ([uid, v]) => {
    const lastHb = Number(v?.lastHeartbeat ?? 0);
    const token = v?.fcmToken as string | undefined;
    const sharing = v?.locationSharingEnabled === true;

    if (sharing && token && now - lastHb > cutoffMs) {
      const msg = {
        message: {
          token,
          data: { action: "revive_service" },
          android: { priority: "HIGH" },
          apns: { headers: { "apns-push-type": "background", "apns-priority": "5" } },
        },
      };
      try {
        const r = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(msg),
        });
        if (r.ok) sent++;
      } catch { /* ignore per-token errors */ }
    }
  });

  await Promise.all(sends);
  return { sent, message: `sent=${sent}` };
}

Deno.serve(async () => {
  const result = await processStaleHeartbeats();
  return new Response(result.message, { status: 200 });
});

// --- Cron scheduling for automatic execution every 30 minutes ---
try {
  const cronEnabled = (Deno.env.get("GROUPSHARING_CRON_ENABLED") || "true").toLowerCase() === "true";
  if (cronEnabled) {
    const spec = Deno.env.get("GROUPSHARING_CRON_SPEC") || "*/30 * * * *"; // default every 30 min
    Deno.cron("groupsharing-heartbeat-monitor", spec, async () => {
      try {
        console.log("Running scheduled heartbeat monitoring...");
        const result = await processStaleHeartbeats();
        console.log(`Heartbeat monitoring completed: ${result.message}`);
      } catch (e) {
        console.error("Cron heartbeat monitoring error:", (e as Error).message);
      }
    });
    console.log(`Groupsharing cron scheduled: ${spec}`);
  }
} catch {
  // Deno.cron may not be available in older runtimes; ignore
}


