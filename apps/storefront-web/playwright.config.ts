import { defineConfig, devices } from "@playwright/test";

// App-local E2E smoke tests against the production build (vite preview).
// Cross-app journeys live in tests/e2e at the repository root.
export default defineConfig({
  testDir: "tests/e2e",
  retries: process.env.CI ? 1 : 0,
  use: { baseURL: "http://localhost:7174", trace: "on-first-retry" },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: "npm run build && npm run preview",
    url: "http://localhost:7174",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
