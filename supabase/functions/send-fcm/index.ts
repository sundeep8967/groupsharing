// Supabase Edge Function: send-fcm
// Sends a data-only FCM message using Firebase HTTP v1 API.
// Expects secrets:
//  - FIREBASE_SERVICE_ACCOUNT: full JSON service account
//  - FCM_PROJECT_ID: project_id string
// Request body (POST application/json):
//  { token?: string, topic?: string, data?: Record<string,string> }

// Jose v4 via deno.land (safer for Edge Runtime than npm specifier)
import {
  importPKCS8,
  SignJWT,
} from "https://deno.land/x/jose@v4.14.4/index.ts";

interface ServiceAccount {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  client_id: string;
  auth_uri: string;
  token_uri: string;
  auth_provider_x509_cert_url: string;
  client_x509_cert_url: string;
  universe_domain?: string;
}

const CORS_HEADERS: HeadersInit = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  // Build a Google OAuth JWT for service account
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: sa.client_email,
    sub: sa.client_email,
    aud: "https://oauth2.googleapis.com/token",
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    iat: now,
    exp: now + 3600, // 1 hour
  };

  // SA private_key is in PKCS#8 PEM
  const alg = "RS256" as const;
  const key = await importPKCS8(sa.private_key, alg);

  const jwt = await new SignJWT({ scope: payload.scope })
    .setProtectedHeader({ alg, typ: "JWT" })
    .setIssuer(payload.iss)
    .setSubject(payload.sub)
    .setAudience(payload.aud)
    .setIssuedAt(payload.iat)
    .setExpirationTime(payload.exp)
    .sign(key);

  // Exchange JWT for access_token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenRes.ok) {
    const text = await tokenRes.text();
    throw new Error(`Token exchange failed: ${tokenRes.status} ${text}`);
  }

  const tokenJson = await tokenRes.json();
  return tokenJson.access_token as string;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  try {
    const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    const projectId = Deno.env.get("FCM_PROJECT_ID");

    if (!saJson) {
      return jsonResponse(500, { error: "Missing FIREBASE_SERVICE_ACCOUNT secret" });
    }
    if (!projectId) {
      return jsonResponse(500, { error: "Missing FCM_PROJECT_ID secret" });
    }

    let body: any;
    try {
      body = await req.json();
    } catch (_) {
      return jsonResponse(400, { error: "Invalid JSON body" });
    }

    const { token, topic, data, android, apns, webpush, validateOnly } = body ?? {};
    if (!token && !topic) {
      return jsonResponse(400, { error: "Provide either 'token' or 'topic'" });
    }

    // Parse service account
    let sa: ServiceAccount;
    try {
      sa = JSON.parse(saJson) as ServiceAccount;
    } catch (e) {
      return jsonResponse(500, { error: "Invalid FIREBASE_SERVICE_ACCOUNT JSON" });
    }

    // Mint access token
    const accessToken = await getAccessToken(sa);

    // Construct FCM message
    const message: Record<string, unknown> = {
      data: Object.fromEntries(
        Object.entries((data ?? {})).map(([k, v]) => [String(k), String(v)])
      ),
    };
    if (token) message["token"] = String(token);
    if (topic) message["topic"] = String(topic);

    // Optional platform configs. Default to HIGH priority on Android for wake behavior.
    if (android || true) {
      const baseAndroid = { priority: "HIGH" } as Record<string, unknown>;
      // shallow merge user-provided android override if present
      message["android"] = { ...baseAndroid, ...(android ?? {}) };
    }
    if (apns) {
      message["apns"] = apns;
    }
    if (webpush) {
      message["webpush"] = webpush;
    }

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const fcmRes = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message, validate_only: Boolean(validateOnly) }),
    });

    const resText = await fcmRes.text();
    if (!fcmRes.ok) {
      return jsonResponse(fcmRes.status, {
        error: "FCM send failed",
        details: resText,
      });
    }

    let resJson: unknown;
    try {
      resJson = JSON.parse(resText);
    } catch {
      resJson = { raw: resText };
    }

    return jsonResponse(200, {
      ok: true,
      result: resJson,
    });
  } catch (e) {
    return jsonResponse(500, { error: (e as Error).message });
  }
});

// --- Optional: Native cron scheduling (Supabase supports Deno.cron) ---
// Enable by setting: CRON_ENABLED=true
// Configure with:
//  - CRON_SPEC         (e.g., "*/15 * * * *")
//  - CRON_TOPIC        (or CRON_TOKEN)
//  - CRON_TOKEN        (device token alternative to topic)
//  - CRON_DATA         (JSON string of data payload)
//  - CRON_ANDROID      (JSON string for android config)
//  - CRON_APNS         (JSON string for apns config)
//  - CRON_WEBPUSH      (JSON string for webpush config)
//  - CRON_VALIDATE_ONLY ("true"/"false")
try {
  const cronEnabled = (Deno.env.get("CRON_ENABLED") || "").toLowerCase() === "true";
  if (cronEnabled) {
    const spec = Deno.env.get("CRON_SPEC") || "*/15 * * * *"; // default every 15 min
    Deno.cron("send-fcm-cron", spec, async () => {
      try {
        const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
        const projectId = Deno.env.get("FCM_PROJECT_ID");
        if (!saJson || !projectId) {
          console.error("Cron skipped: missing FIREBASE_SERVICE_ACCOUNT or FCM_PROJECT_ID");
          return;
        }

        // Parse service account
        let sa: ServiceAccount;
        try {
          sa = JSON.parse(saJson) as ServiceAccount;
        } catch {
          console.error("Cron skipped: invalid FIREBASE_SERVICE_ACCOUNT JSON");
          return;
        }

        const accessToken = await getAccessToken(sa);

        const topic = Deno.env.get("CRON_TOPIC") || undefined;
        const token = Deno.env.get("CRON_TOKEN") || undefined;
        if (!topic && !token) {
          console.error("Cron skipped: set CRON_TOPIC or CRON_TOKEN");
          return;
        }

        const parseJson = (s?: string | null) => {
          if (!s) return undefined;
          try { return JSON.parse(s); } catch { return undefined; }
        };

        const data = parseJson(Deno.env.get("CRON_DATA")) || { wake: "1" };
        const android = parseJson(Deno.env.get("CRON_ANDROID"));
        const apns = parseJson(Deno.env.get("CRON_APNS"));
        const webpush = parseJson(Deno.env.get("CRON_WEBPUSH"));
        const validateOnly = (Deno.env.get("CRON_VALIDATE_ONLY") || "false").toLowerCase() === "true";

        const message: Record<string, unknown> = {
          data: Object.fromEntries(Object.entries(data).map(([k, v]) => [String(k), String(v as unknown as string)])),
        };
        if (topic) message["topic"] = topic;
        if (token) message["token"] = token;
        message["android"] = { priority: "HIGH", ...(android ?? {}) };
        if (apns) message["apns"] = apns;
        if (webpush) message["webpush"] = webpush;

        const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
        const res = await fetch(fcmUrl, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ message, validate_only: validateOnly }),
        });
        const text = await res.text();
        if (!res.ok) {
          console.error("Cron FCM failed:", res.status, text);
        } else {
          console.log("Cron FCM ok:", text);
        }
      } catch (e) {
        console.error("Cron error:", (e as Error).message);
      }
    });
  }
} catch {
  // Deno.cron may not be available in older runtimes; ignore
}
