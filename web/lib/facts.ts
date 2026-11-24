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
  { label: "Precio", value: "Gratis. Todas las funciones están disponibles sin cuenta ni período de prueba." },
  { label: "Mac", value: "macOS 14 Sonoma o posterior en Apple Silicon e Intel. Con firma del desarrollador y notarización de Apple." },
  { label: "Última versión para Mac", value: `${VERSION} (${RELEASES[0].date}) · ${DMG_SIZE}. [Instalador y pasos para Mac](${DOWNLOAD_PATHS.es}#mac)` },
  { label: "Windows", value: `[Versión preliminar de Pocket ${WINDOWS_VERSION}](${DOWNLOAD_PATHS.es}#windows) para Windows 11 en equipos con Intel, AMD o ARM. El instalador preliminar no tiene firma.` },
  { label: "Cómo funciona", value: "Registra tus gastos e ingresos a mano, sin conectar una cuenta bancaria." },
  {
    label: "Proyección del saldo",
    value: "La vista Plan estima cómo podría cambiar tu saldo en 1, 3, 6 o 12 meses a partir de los pagos e ingresos que programaste. En Mac, también puede incluir una semana típica de gastos cotidianos según tus movimientos recientes.",
  },
  {
    label: "Disponible hasta el próximo cobro",
    value: "En Mac, elige tu próxima fecha de cobro y el saldo mínimo que quieres conservar. Pocket resta ese mínimo del saldo más bajo previsto antes del cobro. La estimación incluye tus gastos habituales si tienes suficiente historial y deja fuera los ingresos sin confirmar. [Configura tu fecha de cobro y saldo mínimo](/guides/freelance-income/#before-payday).",
  },
  {
    label: "Registro rápido en Mac",
    value: "Selecciona Undo en la confirmación para deshacer el movimiento que acabas de registrar. En el menú More del panel de la barra de menús, elige Hide Balance para ocultar el monto mientras registras movimientos. [Oculta el saldo de la barra de menús](/guides/menu-bar-balance/#screen-sharing).",
  },
  {
    label: "Recordatorios de suscripciones",
    value: "Los recordatorios de renovación son gratuitos en Mac. Agrega el servicio a mano y activa las notificaciones. De forma predeterminada, el aviso llega dos días antes de la renovación a las 10 a. m. Puedes elegir entre 1 y 365 días de anticipación y fijar la hora, o programar un aviso único para una renovación. [Configura los recordatorios](/guides/track-subscriptions/#renewal-reminders).",
  },
  {
    label: "Datos",
    value: "Por defecto, el registro se queda en tu dispositivo. En Mac, Pocket lo guarda en ~/Library/Application Support/Pocket/ledger.json, mantiene siete copias de seguridad diarias, permite importar y exportar en JSON y exportar en CSV.",
  },
  {
    label: "Sincronización opcional",
    value: "Configura tu propio proyecto de Supabase y [vincula tu celular](/guides/self-hosting/) para usar el mismo registro en la app web de Pocket. En Mac, puedes usar Pocket sin conexión y sin cuenta.",
  },
  { label: "Monedas", value: "Puedes elegir cualquier moneda estándar, una por registro. Al cambiarla, se actualiza la etiqueta de los montos y se conservan sus valores." },
  {
    label: "Acceso desde el celular",
    value: `Una vez configurada la sincronización, vincula tu celular para usar la app web de Pocket. [Configura y vincula la app web](${DOWNLOAD_PATHS.es}#web).`,
  },
  { label: "Autor", value: "[Orlando Ascanio](https://www.orlandoascanio.com), desarrollador independiente." },
  { label: "Código fuente", value: `Consulta el código público de Pocket en [GitHub](${REPO_URL}).` },
];

export const AT_A_GLANCE_ES =
  "Pocket para Mac (PocketLeft) es una app gratuita de control de gastos que funciona sin conexión y está disponible en pocketleft.app. Registra ingresos y gastos a mano para ver tu saldo junto al reloj de la Mac. La vista Plan estima cuánto te quedará después de tus próximos pagos y cobros. Por defecto, Pocket guarda tu registro en la Mac y funciona sin vincular un banco ni crear una cuenta.";
