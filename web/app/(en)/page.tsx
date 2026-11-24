import type { Metadata } from "next";
import { HomePage } from "@/components/HomePage";
import { HOMEPAGE_PATHS, alternateLanguages } from "@/lib/locale";

export const metadata: Metadata = {
  alternates: {
    canonical: HOMEPAGE_PATHS.en,
    languages: alternateLanguages(HOMEPAGE_PATHS),
  },
};

export default function Home() {
  return <HomePage locale="en" />;
}
