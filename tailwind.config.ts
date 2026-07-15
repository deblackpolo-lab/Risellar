import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx,mdx}"
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          emerald: "var(--color-primary)",
          green: "var(--color-secondary)",
          gold: "var(--color-accent)",
          cream: "var(--color-cream)",
          charcoal: "var(--color-charcoal)"
        },
        status: {
          success: "var(--color-success)",
          warning: "var(--color-warning)",
          danger: "var(--color-danger)",
          info: "var(--color-info)",
          muted: "var(--color-muted)"
        }
      },
      fontFamily: {
        sans: ["var(--font-sans)", "Inter", "system-ui", "sans-serif"]
      },
      borderRadius: {
        risellar: "var(--radius-md)",
        "risellar-lg": "var(--radius-lg)"
      },
      boxShadow: {
        risellar: "var(--shadow-sm)",
        "risellar-md": "var(--shadow-md)"
      }
    }
  },
  plugins: []
};

export default config;
