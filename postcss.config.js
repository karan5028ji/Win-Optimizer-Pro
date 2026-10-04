export default {
  plugins: {
    // Tailwind v4 ships as a PostCSS plugin under its own package name; the bare
    // `tailwindcss` plugin entry that v3 used no longer exists.
    "@tailwindcss/postcss": {},
    autoprefixer: {},
  },
};
