/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        accent: {
          300: "#c4b5fd",
          400: "#a78bfa",
          500: "#8b5cf6",
          600: "#7c3aed",
          700: "#6d28d9",
          800: "#5b21b6",
          900: "#4c1d95",
          950: "#2e1065",
        },
        panel: {
          DEFAULT: "#131316",
          hover: "#1c1c20",
          border: "#27272a",
        },
      },
      boxShadow: {
        "accent-glow": "0 0 0 1px rgba(139,92,246,.4), 0 0 22px -6px rgba(139,92,246,.55)",
      },
      transitionTimingFunction: {
        smooth: "cubic-bezier(0.4, 0, 0.2, 1)",
      },
    },
  },
  plugins: [],
};
