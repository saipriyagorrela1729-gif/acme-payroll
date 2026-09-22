import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// Dev: proxy /api to the Rails server. Prod: build lands in ../public so
// Rails serves the SPA from a single origin (see docs/architecture.md).
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': 'http://localhost:3000',
    },
  },
  build: {
    outDir: '../public',
    emptyOutDir: true,
  },
})