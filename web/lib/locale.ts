import { DOWNLOAD_PAGE } from "@/lib/site";

export type Locale = "en" | "es";

export const HOMEPAGE_PATHS = { en: "/", es: "/es/" } as const;

export const DOWNLOAD_PATHS = { en: DOWNLOAD_PAGE, es: "/es/download/" } as const;
export const ABOUT_PATHS = { en: "/about/", es: "/es/about/" } as const;

export const LOCALIZED_PAGES = [HOMEPAGE_PATHS, DOWNLOAD_PATHS, ABOUT_PATHS];

export function alternateLanguages(paths: Record<Locale, string>, origin = "") {
  const en = origin + paths.en;
  return { en, es: origin + paths.es, "x-default": en };
}

export const SPANISH_DESCRIPTION = "Controla tus gastos sin conexión con Pocket, gratis para Mac y Windows. Registra tus compras, consulta tu saldo y planifica tus próximos pagos.";
