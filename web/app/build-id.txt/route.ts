// The commit this deploy was built from. Netlify sets COMMIT_REF during the build, and the
// response is prerendered then, so the IndexNow workflow can wait for its own commit to go live
// before submitting. Local builds report "local".
export const dynamic = "force-static";

export function GET() {
  return new Response(process.env.COMMIT_REF ?? "local", {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}
