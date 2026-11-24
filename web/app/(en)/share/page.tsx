import type { Metadata } from "next";
import Home from "../page";

// The link in Pocket's share sheet. It's the homepage under its own path so shared visits can be
// counted (analytics drop query strings). Search engines skip it and treat / as the real page.
export const metadata: Metadata = {
  alternates: { canonical: "/" },
  robots: { index: false, follow: true },
};

export default Home;
