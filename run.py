from __future__ import annotations

import csv
import re
from pathlib import Path

from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

import re

SHOWING_RE = re.compile(r"Showing\s+(\d+)\s*-\s*(\d+)\s+of\s+(\d+)", re.IGNORECASE)

URL = "http://public.cyber.mil/stigs/downloads"
OUT = Path(__file__).resolve().parent / "stigs_downloads.csv"

WS = re.compile(r"\s+")

def clean(s: str) -> str:
    return WS.sub(" ", (s or "").strip())


def get_showing_nums(page) -> tuple[int, int, int]:
    loc = page.locator("text=/Showing\\s+\\d+\\s*-\\s*\\d+\\s+of\\s+\\d+/i").first
    if loc.count() == 0:
        return (0, 0, 0)
    try:
        txt = loc.inner_text().strip()
    except Exception:
        return (0, 0, 0)

    m = SHOWING_RE.search(txt)
    if not m:
        return (0, 0, 0)
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)))

def click_next(page) -> bool:
    """
    Click the pager next arrow and return True only if Showing start number changes.
    """
    before_start, before_end, total = get_showing_nums(page)
    if before_start == 0:
        return False

    # Scope to the pager near the showing text
    showing = page.locator("text=/Showing\\s+\\d+\\s*-\\s*\\d+\\s+of\\s+\\d+/i").first
    pager = showing.locator("xpath=ancestor::*[self::div or self::nav][.//a or .//button][1]")

    # Prefer explicit Next; otherwise take the last control in the pager (your blue arrow)
    next_btn = pager.locator(
        "a[aria-label='Next'],button[aria-label='Next'],a:has-text('›'),button:has-text('›'),a:has-text('>'),button:has-text('>')"
    ).last
    if next_btn.count() == 0:
        next_btn = pager.locator("a,button").last
        if next_btn.count() == 0:
            return False

    # Disabled checks
    aria = (next_btn.get_attribute("aria-disabled") or "").lower()
    if aria == "true":
        return False
    try:
        parent = next_btn.locator("xpath=..")
        cls = (parent.get_attribute("class") or "").lower()
        if "disabled" in cls:
            return False
    except Exception:
        pass

    try:
        next_btn.scroll_into_view_if_needed(timeout=5_000)
    except Exception:
        pass

    try:
        next_btn.click(timeout=5_000)
    except Exception:
        return False

    # Wait until the Showing *start* number changes
    for _ in range(240):  # 240 * 250ms = 60s
        after_start, after_end, _ = get_showing_nums(page)
        if after_start and after_start != before_start:
            return True
        page.wait_for_timeout(250)

    return False






def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context()
        page = context.new_page()

        page.goto(URL, wait_until="domcontentloaded", timeout=60_000)

        # Wait for the table rows to exist (real <table> in your devtools screenshot)
        page.locator("table tbody tr").first.wait_for(timeout=60_000)
        page.locator("text=/Showing\\s+\\d+\\s*-\\s*\\d+\\s+of\\s+\\d+/i").first.wait_for(timeout=60_000)

        rows_out: list[tuple[str, str, str, str]] = []
        seen: set[tuple[str, str, str, str]] = set()

        while True:
            trs = page.locator("table tbody tr")
            row_count = trs.count()

            for i in range(row_count):
                tr = trs.nth(i)

                # Name is in <th scope="row"> ... </th>
                th = tr.locator("th[scope='row']")
                if th.count() == 0:
                    continue
                name = clean(th.first.inner_text())

                # There are two data <td> cells before the link/button cell:
                # td[0] = Download Type, td[1] = Upload Date
                tds = tr.locator("td")
                if tds.count() < 2:
                    continue

                dtype = clean(tds.nth(0).inner_text())
                upload = clean(tds.nth(1).inner_text())

                # Link is on the Download button as data-link (per your screenshot)
                btn = tr.locator("button.downloadButton, button[data-link], a[data-link]").first
                link = clean(btn.get_attribute("data-link") or "")

                rec = (name, dtype, upload, link)
                if name and rec not in seen:
                    seen.add(rec)
                    rows_out.append(rec)
                    

            # next page
            if not click_next(page):
                break

            # Wait for next page to render at least one row
            try:
                page.locator("table tbody tr").first.wait_for(timeout=30_000)
            except PWTimeout:
                break

        browser.close()

    with OUT.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["Name", "Download Type", "Upload Date", "Link"])
        w.writerows(rows_out)
        print(f"Rows written: {len(rows_out)}")

if __name__ == "__main__":
    main()


