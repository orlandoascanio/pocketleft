import { DOWNLOAD_PATHS } from "@/lib/locale";
import { RELEASES } from "@/lib/releases";
import { DMG_SIZE, DOWNLOAD_PAGE, REPO_URL, VERSION, WINDOWS_VERSION } from "@/lib/site";

// The plain facts about Pocket, shared by /about/ and /llms.txt so they can't disagree.
// Values can link with [label](url), like guide text.
export type Fact = { label: string; value: string };

export const FACTS: Fact[] = [
  { label: "Price", value: "Free. Every feature, with no account and no trial." },
  { label: "Mac", value: "macOS 14 Sonoma or later on Apple Silicon and Intel. Developer-signed and Apple-notarized." },
  { label: "Latest Mac version", value: `${VERSION} (${RELEASES[0].date}) · ${DMG_SIZE}. [Mac installer and setup](${DOWNLOAD_PAGE}#mac)` },
  { label: "Windows", value: `[Pocket ${WINDOWS_VERSION} preview](${DOWNLOAD_PAGE}#windows) for Windows 11 on Intel, AMD, and ARM PCs. The preview installer is unsigned.` },
  { label: "How it works", value: "You record money in and out by hand. Pocket does not connect to banks." },
  {
    label: "Balance forecast",
    value: "Plan estimates how your balance could change over 1, 3, 6 or 12 months based on the bills and income you've scheduled. On Mac, it can include a typical week of everyday spending from your recent entries.",
  },
  {
    label: "Available until payday",
    value: "On Mac, choose a payday and a minimum balance to keep. Pocket subtracts your cushion from the lowest projected balance before payday. The estimate includes usual spending when you have enough history and leaves out income awaiting confirmation. [Set your payday and cushion](/guides/freelance-income/#before-payday).",
  },
  {
    label: "Quick Entry on Mac",
    value: "Click Undo on the confirmation to reverse the entry you just added. Choose Hide Balance from the menu bar panel’s More menu to keep the amount private while you log entries. [Hide the menu bar balance](/guides/menu-bar-balance/#screen-sharing).",
  },
  {
    label: "Subscription reminders",
    value: "Mac renewal reminders are free. Enter a service by hand and enable notifications. The default is two days before renewal at 10 a.m. Choose 1–365 days and a time, or set a one-time reminder for a particular renewal. [Set up renewal reminders](/guides/track-subscriptions/#renewal-reminders).",
  },
  {
    label: "Data",
    value: "The ledger stays on your device by default. On Mac, Pocket stores it in ~/Library/Application Support/Pocket/ledger.json, keeps seven daily backups, and supports JSON import and export and CSV export.",
  },
  {
    label: "Optional sync",
    value: "Set up a Supabase project you run and [pair your phone](/guides/self-hosting/) to use the same ledger in the Pocket web app. Local use on Mac works offline without a Pocket account.",
  },
  { label: "Currencies", value: "Any standard currency, one per ledger. Changing it relabels amounts; it does not convert them." },
  {
    label: "Phone access",
    value: "Pair your phone to use the Pocket web app once you've set up sync. [Web app setup and pairing](/download/#web).",
  },
  { label: "Made by", value: "[Orlando Ascanio](https://www.orlandoascanio.com), an independent developer." },
  { label: "Source code", value: `View Pocket's public source on [GitHub](${REPO_URL}).` },
];

// Answer-first summary for /about/: the passage an answer engine is most likely to quote.
export const AT_A_GLANCE =
  "Pocket for Mac (PocketLeft) is a free, offline expense tracker at pocketleft.app. Enter income and expenses by hand to see your recorded balance beside the Mac clock. Plan estimates what you'll have left after upcoming bills and income. Pocket keeps your ledger on your Mac by default and works without a bank connection or account.";

export const FACTS_ES: Fact[] = [
  { label: "Precio", value: "Gratis. Puedes usar todas las funciones sin abrir una cuenta ni activar un período de prueba." },
  { label: "Mac", value: "macOS 14 Sonoma o posterior en Apple Silicon e Intel. Con firma del desarrollador y notarización de Apple." },
  { label: "Última versión para Mac", value: `${VERSION} (${RELEASES[0].date}) · ${DMG_SIZE}. [Instalador y pasos para Mac](${DOWNLOAD_PATHS.es}#mac)` },
  { label: "Windows", value: `[Versión preliminar de Pocket ${WINDOWS_VERSION}](${DOWNLOAD_PATHS.es}#windows) para Windows 11 en equipos con Intel, AMD o ARM. El instalador preliminar no tiene firma.` },
  { label: "Cómo funciona", value: "Registra tus gastos e ingresos a mano, sin conectar una cuenta bancaria." },
  {
    label: "Proyección del saldo",
    value: "En Plan puedes ver cómo cambiaría tu saldo en 1, 3, 6 o 12 meses con los pagos e ingresos que programaste. En Mac, Pocket también puede estimar los gastos de una semana normal a partir de tus movimientos recientes.",
  },
  {
    label: "Disponible hasta el próximo cobro",
    value: "En Mac, elige cuándo vuelves a cobrar y qué saldo mínimo quieres mantener. Pocket busca el saldo más bajo previsto antes del cobro y le resta el mínimo que elegiste. El cálculo deja fuera los ingresos sin confirmar y cuenta los gastos habituales si ya tienes suficiente historial. [Configura tu fecha de cobro y saldo mínimo](/guides/freelance-income/#before-payday).",
  },
  {
    label: "Registro rápido en Mac",
    value: "Si registras un movimiento por error, pulsa Undo en la confirmación. Para ocultar el saldo mientras anotas un movimiento, abre el menú More del panel y elige Hide Balance. [Oculta el saldo de la barra de menús](/guides/menu-bar-balance/#screen-sharing).",
  },
  {
    label: "Recordatorios de suscripciones",
    value: "En Mac puedes recibir avisos de renovación gratis. Agrega el servicio y activa las notificaciones. Pocket te avisa dos días antes a las 10 a. m. por defecto. Puedes cambiar la hora, elegir entre 1 y 365 días de anticipación o programar un aviso para una sola renovación. [Configura los recordatorios](/guides/track-subscriptions/#renewal-reminders).",
  },
  {
    label: "Datos",
    value: "Por defecto, Pocket guarda el registro en tu dispositivo. En Mac, el archivo está en ~/Library/Application Support/Pocket/ledger.json y Pocket conserva siete copias de seguridad diarias. Puedes importar y exportar en JSON o exportar en CSV.",
  },
  {
    label: "Sincronización opcional",
    value: "Configura tu propio proyecto de Supabase y [vincula tu celular](/guides/self-hosting/) para usar el mismo registro en la app web de Pocket. En Mac, puedes usar Pocket sin conexión y sin cuenta.",
  },
  { label: "Monedas", value: "Elige una moneda estándar por registro. Si la cambias, Pocket actualiza cómo se muestran los montos y conserva las cifras que ingresaste." },
  {
    label: "Acceso desde el celular",
    value: `Después de configurar la sincronización, vincula el celular y abre tu registro en el navegador. [Configura y vincula la app web](${DOWNLOAD_PATHS.es}#web).`,
  },
  { label: "Autor", value: "[Orlando Ascanio](https://www.orlandoascanio.com), desarrollador independiente." },
  { label: "Código fuente", value: `Consulta el código público de Pocket en [GitHub](${REPO_URL}).` },
];

export const AT_A_GLANCE_ES =
  "Ingresa el saldo de hoy y anota tus gastos e ingresos. Pocket actualiza el saldo en la barra de menús de la Mac cada vez que registras un movimiento. Es gratis, funciona sin conexión y guarda el registro en tu Mac por defecto.";
