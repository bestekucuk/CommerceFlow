import { expect, test } from "@playwright/test";

test("home page shows the application title", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1, name: "CommerceFlow Admin" })).toBeVisible();
});
