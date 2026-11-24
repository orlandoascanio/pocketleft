import { DownloadPage, downloadMetadata } from "@/components/DownloadPage";

export const metadata = downloadMetadata("en");

export default function Download() {
  return <DownloadPage locale="en" />;
}
