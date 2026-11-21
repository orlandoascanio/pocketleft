import { MenuBarStrip } from "@/components/MenuBar";

// Three small looping demos of real Pocket behavior, drawn in HTML and animated with CSS only.
function Swap({ from, to }: { from: string; to: string }) {
  return (
    <span className="swap">
      <span className="swap-a">{from}</span>
      <span className="swap-b">{to}</span>
    </span>
  );
}

function Card({ label, href, dark, children }: { label: string; href: string; dark?: boolean; children: React.ReactNode }) {
  return (
    <a className={dark ? "bento-card dark" : "bento-card"} href={href}>
      <div className="bento-demo" aria-hidden="true">
        {children}
      </div>
      <div className="bento-foot">
        <span>{label}</span>
        <span className="bento-more" aria-hidden="true"><span>→</span></span>
      </div>
    </a>
  );
}

export function Bento() {
  return (
    <div className="bento">
      <Card label="Menu bar" href="#tour">
        <div className="demo-menu">
          <MenuBarStrip>
            <Swap from="$337.03" to="$330.53" />
          </MenuBarStrip>
          <div className="demo-toast">☕ Coffee −$6.50</div>
          <div className="demo-keys">
            <span className="chip key-hit">
              Coffee <kbd>⌘1</kbd>
            </span>
            <span className="chip">
              Lunch <kbd>⌘2</kbd>
            </span>
          </div>
        </div>
      </Card>

      <Card label="Plan ahead" href="#plan" dark>
        <div className="demo-plan">
          <div className="demo-plan-head">
            <b>Lasts past Jan 10</b>
            <small>On Jan 10: $2,547.03</small>
          </div>
          <svg className="demo-chart" viewBox="0 0 300 140">
            <path className="demo-chart-grid" d="M0 35H300M0 70H300M0 105H300" />
            <path className="demo-chart-area" d="M4 118V88H120V58H220V30H296V136H4Z" />
            <path className="demo-chart-line" pathLength="1" d="M4 118V88H120V58H220V30H296" />
            <circle cx="4" cy="88" r="3.5" />
            <circle cx="120" cy="58" r="3.5" />
            <circle cx="220" cy="30" r="3.5" />
          </svg>
          <div className="demo-axis">
            <span>Oct</span>
            <span>Nov</span>
            <span>Dec</span>
            <span>Jan</span>
          </div>
        </div>
      </Card>

      <Card label="Waiting for you" href="#waiting">
        <div className="demo-wait">
          <div className="demo-wait-card">
            <div className="demo-wait-row">
              <span>
                <svg viewBox="0 0 16 16" aria-hidden="true">
                  <circle cx="8" cy="8" r="6.5" />
                  <path d="M8 4.5V8l2.2 1.6" />
                </svg>
                Client A
              </span>
              <b className="in">+$750.00</b>
            </div>
            <div className="demo-wait-row">
              <small>Was due Oct 9</small>
              <span className="demo-wait-btns">
                <span className="mini got">Got it</span>
                <span className="mini">Skip</span>
              </span>
            </div>
          </div>
          <div className="demo-wait-done">✓ Logged +$750.00 today</div>
          <div className="demo-wait-bal">
            Money left <Swap from="$337.03" to="$1,087.03" />
          </div>
        </div>
      </Card>
    </div>
  );
}
