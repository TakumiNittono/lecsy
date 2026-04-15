// supabase/functions/_shared/openai.ts
// Purpose: OpenAI Chat Completions 呼び出しを共通化し、
// 429 / 5xx の transient error に対して指数バックオフでリトライする。
//
// なぜ必要か:
//  - 500 ユーザー規模の本番で、OpenAI 側の 429(Rate limit) や
//    503(Service unavailable) は普通に起きる。
//  - 現状はリトライなしで即 500 を返してしまい、ユーザーが手動で
//    連打 → その都度 OpenAI 課金が発生する悪循環になっていた。
//  - サーバー側で賢くリトライすれば、ユーザーは成功レスポンスを
//    受け取れるし、課金も安定する。
//
// ポリシー:
//  - 最大 3 回リトライ (計 4 試行)。
//  - 429 / 500 / 502 / 503 / 504 のみリトライ対象。400/401/404 は即失敗。
//  - バックオフ: 500ms → 1.5s → 3.5s (jitter あり)。
//  - Retry-After ヘッダがあれば尊重する (最大 10 秒まで)。
//  - 呼び出し元でタイムアウトしている場合は AbortSignal で中断可能。

export interface OpenAICallOptions {
  apiKey: string;
  body: Record<string, unknown>;
  signal?: AbortSignal;
  maxRetries?: number;
}

const RETRYABLE_STATUSES = new Set([429, 500, 502, 503, 504]);

export async function callOpenAIChat(
  opts: OpenAICallOptions,
): Promise<Response> {
  const maxRetries = opts.maxRetries ?? 3;
  let lastErr: unknown;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    if (opts.signal?.aborted) {
      throw new Error("aborted");
    }
    try {
      const resp = await fetch(
        "https://api.openai.com/v1/chat/completions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${opts.apiKey}`,
          },
          body: JSON.stringify(opts.body),
          signal: opts.signal,
        },
      );

      if (resp.ok) return resp;

      if (!RETRYABLE_STATUSES.has(resp.status) || attempt === maxRetries) {
        return resp; // 呼び出し元がそのまま扱う
      }

      // Drain the body so the connection is reusable and memory is freed.
      try {
        await resp.text();
      } catch (_) {
        // ignore
      }

      const retryAfter = parseRetryAfter(resp.headers.get("retry-after"));
      const backoff = retryAfter ?? computeBackoff(attempt);
      console.warn(
        `OpenAI ${resp.status} — retry ${attempt + 1}/${maxRetries} in ${backoff}ms`,
      );
      await sleep(backoff, opts.signal);
      continue;
    } catch (err) {
      lastErr = err;
      // network failure — retry unless we're out of attempts or aborted
      if (opts.signal?.aborted) throw err;
      if (attempt === maxRetries) throw err;
      const backoff = computeBackoff(attempt);
      console.warn(
        `OpenAI network error — retry ${attempt + 1}/${maxRetries} in ${backoff}ms: ${err}`,
      );
      await sleep(backoff, opts.signal);
      continue;
    }
  }

  throw lastErr ?? new Error("openai_unreachable");
}

function computeBackoff(attempt: number): number {
  // 500ms * 3^attempt  (500, 1500, 4500) with ±25% jitter, capped at 8s.
  const base = Math.min(500 * Math.pow(3, attempt), 8000);
  const jitter = base * (0.75 + Math.random() * 0.5);
  return Math.round(jitter);
}

function parseRetryAfter(header: string | null): number | null {
  if (!header) return null;
  const seconds = Number(header);
  if (!Number.isNaN(seconds) && seconds >= 0) {
    return Math.min(seconds * 1000, 10_000);
  }
  // HTTP-date form — rarely used by OpenAI, but handle defensively.
  const dateMs = Date.parse(header);
  if (!Number.isNaN(dateMs)) {
    return Math.min(Math.max(0, dateMs - Date.now()), 10_000);
  }
  return null;
}

function sleep(ms: number, signal?: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    const t = setTimeout(resolve, ms);
    if (signal) {
      signal.addEventListener("abort", () => {
        clearTimeout(t);
        reject(new Error("aborted"));
      }, { once: true });
    }
  });
}
