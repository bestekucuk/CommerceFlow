import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { App } from "../../src/app/App";

describe("App", () => {
  it("renders the application title as the main heading", () => {
    render(<App />);
    expect(screen.getByRole("heading", { level: 1, name: "CommerceFlow Store" })).toBeInTheDocument();
  });
});
