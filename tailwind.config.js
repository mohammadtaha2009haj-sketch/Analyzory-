/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        luxury: {
          black: '#0a0a0a',
          blue: '#1e3a8a',
          lightblue: '#60a5fa',
          green: '#10b981',
          gold: '#d4af37'
        }
      }
    },
  },
  plugins: [],
}
