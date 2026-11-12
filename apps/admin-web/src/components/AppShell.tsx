import type { ReactNode } from "react";

type AppShellProps = {
  title: string;
  children: ReactNode;
};

export function AppShell({ title, children }: AppShellProps) {
  return (
    <>
      <header>
        <h1>{title}</h1>
      </header>
      <main>{children}</main>
    </>
  );
}
