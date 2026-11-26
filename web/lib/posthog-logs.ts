import { SeverityNumber } from "@opentelemetry/api-logs";
import { OTLPLogExporter } from "@opentelemetry/exporter-logs-otlp-http";
import { resourceFromAttributes } from "@opentelemetry/resources";
import { BatchLogRecordProcessor, LoggerProvider } from "@opentelemetry/sdk-logs";

const posthogToken = process.env.NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN;
const posthogHost = process.env.NEXT_PUBLIC_POSTHOG_HOST;

let loggerProvider: LoggerProvider | undefined;
let posthogLogger: ReturnType<LoggerProvider["getLogger"]> | undefined;
let shutdownHookRegistered = false;

export function getPostHogLogger() {
  if (posthogLogger) return posthogLogger;

  if (!posthogToken || !posthogHost) {
    if (process.env.NODE_ENV !== "production") {
      const missingVariable = posthogToken
        ? "NEXT_PUBLIC_POSTHOG_HOST"
        : "NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN";
      console.warn(
        `${missingVariable} variable required by PostHog is missing or un-configured, this causes events to be silently missed. This error stops appearing once ${missingVariable} is configured`,
      );
    }
    return undefined;
  }

  loggerProvider = new LoggerProvider({
    resource: resourceFromAttributes({
      "service.name": "pocket-web",
      "deployment.environment": process.env.NODE_ENV ?? "development",
    }),
    processors: [
      new BatchLogRecordProcessor({
        exporter: new OTLPLogExporter({
          url: `${posthogHost.replace(/\/$/, "")}/i/v1/logs`,
          headers: {
            Authorization: `Bearer ${posthogToken}`,
            "Content-Type": "application/json",
          },
        }),
      }),
    ],
  });
  posthogLogger = loggerProvider.getLogger("pocket-web.posthog");

  if (!shutdownHookRegistered) {
    shutdownHookRegistered = true;
    process.once("beforeExit", () => {
      void loggerProvider?.forceFlush().catch(() => {});
    });
  }

  return posthogLogger;
}

export function logPostHogServerStartup(stage: "exporter_configured" | "instrumentation_registered") {
  getPostHogLogger()?.emit({
    body: "PostHog server log capture initialized",
    severityNumber: SeverityNumber.INFO,
    attributes: { event: "server_log_capture_initialized", stage },
  });
}
