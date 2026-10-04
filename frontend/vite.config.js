import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // In local dev, forward API calls to the Node API (docker-compose or `npm run dev` in ../api).
    proxy: { '/api': process.env.VITE_API_PROXY || 'http://localhost:3000' },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/setupTests.js',
    coverage: { reporter: ['text', 'lcov'] },
  },
});
