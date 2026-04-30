// k-deepgram-token: Public Deepgram short-lived token for /k (Hospital Live Interpreter).
// No auth, no plan check. 15-minute TTL. Re-uses existing DEEPGRAM_ADMIN_KEY / DEEPGRAM_PROJECT_ID secrets.

const DEEPGRAM_ADMIN_KEY = Deno.env.get('DEEPGRAM_ADMIN_KEY');
const DEEPGRAM_PROJECT_ID = Deno.env.get('DEEPGRAM_PROJECT_ID');

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS_HEADERS });

  if (!DEEPGRAM_ADMIN_KEY || !DEEPGRAM_PROJECT_ID) {
    return json({ error: 'server_misconfigured' }, 500);
  }

  // encoding は省略 → MediaRecorder の WebM/Opus を Deepgram が autodetect
  const params = new URLSearchParams({
    model: 'nova-3',
    language: 'en-US',
    smart_format: 'true',
    punctuate: 'true',
    interim_results: 'true',
    endpointing: '300',
  });

  const tokenRes = await fetch(
    `https://api.deepgram.com/v1/projects/${DEEPGRAM_PROJECT_ID}/keys`,
    {
      method: 'POST',
      headers: {
        Authorization: `Token ${DEEPGRAM_ADMIN_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        comment: 'k-public-interpreter',
        scopes: ['usage:write'],
        time_to_live_in_seconds: 900,
      }),
    }
  );

  if (!tokenRes.ok) {
    const detail = await tokenRes.text();
    return json({ error: 'token_mint_failed', status: tokenRes.status, detail }, 502);
  }

  const { key } = await tokenRes.json();
  return json({
    token: key,
    url: `wss://api.deepgram.com/v1/listen?${params.toString()}`,
    ttl_seconds: 900,
  }, 200);
});

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}
