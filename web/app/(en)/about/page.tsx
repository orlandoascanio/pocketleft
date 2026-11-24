import { AboutPage, aboutMetadata } from "@/components/AboutPage";

export const metadata = aboutMetadata("en");

export default function About() {
  return <AboutPage locale="en" />;
}
