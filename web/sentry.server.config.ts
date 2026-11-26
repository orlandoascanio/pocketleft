// Initialize Sentry for server requests.
// Keep privacy controls shared with the browser; configure the DSN in Netlify.
// https://docs.sentry.io/platforms/javascript/guides/nextjs/

import * as Sentry from "@sentry/nextjs";
import { sentryOptions } from "./lib/sentry";

Sentry.init(sentryOptions);
