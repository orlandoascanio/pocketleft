// Prerender the deployed Git commit so IndexNow can wait for that commit to go live.
export const dynamic = "force-static";

export function GET() {
  return new Response(process.env.VERCEL_GIT_COMMIT_SHA ?? process.env.COMMIT_REF ?? "local", {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}
