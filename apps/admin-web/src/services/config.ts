import type { AppConfig } from "../types/config";

// Public build-time configuration. Never put secrets in VITE_* variables.
export const appConfig: AppConfig = {
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL ?? "/api",
};
