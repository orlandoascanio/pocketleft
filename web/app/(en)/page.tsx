import type { Metadata } from "next";
import { HomePage } from "@/components/HomePage";
import { HOMEPAGE_PATHS } from "@/lib/locale";

export const metadata: Metadata = {
  alternates: {
    canonical: HOMEPAGE_PATHS.en,
    languages: { ...HOMEPAGE_PATHS, "x-default": HOMEPAGE_PATHS.en },
  },
};

export default function Home() {
  return <HomePage locale="en" />;
}
