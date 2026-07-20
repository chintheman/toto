import { useState, useEffect, useRef, type ReactNode } from "react";
import { theme } from "../../shared/palette";

export { theme };

// ─── Scroll-Reveal Section ─────────────────────────────────────────────────

function useScrollReveal() {
  const ref = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) { setVisible(true); observer.unobserve(el); } },
      { threshold: 0.15, rootMargin: "0px 0px -50px 0px" }
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);
  return { ref, visible };
}

export function Section({ children, className = "" }: { children: ReactNode; className?: string }) {
  const { ref, visible } = useScrollReveal();
  return (
    <div ref={ref} className={`transition-all duration-700 ease-out ${visible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"} ${className}`}>
      {children}
    </div>
  );
}

// ─── Scribble Divider ──────────────────────────────────────────────────────

export function ScribbleDivider({ color = theme.beigeDark }: { color?: string }) {
  const line = (key: number) => (
    <svg key={key} width="80" height="12" viewBox="0 0 80 12" fill="none" className="flex-shrink-0">
      <path d="M2 6 C8 2, 12 10, 18 6 C24 2, 28 10, 34 6 C40 2, 44 10, 50 6 C56 2, 60 10, 66 6 C72 2, 76 10, 78 6"
        stroke={color} strokeWidth="1.5" strokeLinecap="round" fill="none" />
    </svg>
  );
  return (
    <div className="flex items-center gap-3 my-12 justify-center" role="separator" aria-orientation="horizontal">
      {line(0)}<span className="text-xs tracking-widest uppercase" style={{ color: `${color}99` }}>•</span>{line(1)}
    </div>
  );
}
