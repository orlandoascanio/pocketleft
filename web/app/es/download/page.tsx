import { DownloadPage, downloadMetadata } from "@/components/DownloadPage";

export const metadata = downloadMetadata("es");

export default function Download() {
  return <DownloadPage locale="es" />;
}
