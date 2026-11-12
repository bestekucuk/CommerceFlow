import { AppShell } from "../components/AppShell";
import { appConfig } from "../services/config";

export function App() {
  return (
    <AppShell title="CommerceFlow Store">
      <p>Scaffold only — no features yet.</p>
      <p>
        API base URL: <code>{appConfig.apiBaseUrl}</code>
      </p>
    </AppShell>
  );
}
