import * as Sentry from "@sentry/nextjs";
import { sentryOptions } from "./lib/sentry";

if (process.env.NEXT_PUBLIC_SENTRY_DSN && !/^\/app(?:\/|$)/.test(window.location.pathname)) {
  Sentry.init(sentryOptions);
}

export const onRouterTransitionStart = Sentry.captureRouterTransitionStart;
