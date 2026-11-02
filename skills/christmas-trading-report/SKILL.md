---
name: christmas-trading-report
description: Use when someone asks for a Christmas trading or stock briefing, report or summary to be sent or emailed. Produces a one-page HTML briefing and emails it to the person asking.
---

# Christmas stock briefing

How Wilderness wants the morning briefing done: the same sections, in the same order, every time, with every
number taken from this run's tool results.

## 1. Gather the facts

Use the agent's own tools, one question each. Sales data runs to 3 November 2026.

1. `retail_analyst`: "Tent units and net sales from 1 to 3 November 2026, and from 1 to 3 November 2025."
2. `retail_analyst`: "Which stores will run out of tents before 24 December, how many tents short, and on what day?"
3. `retail_analyst`: "Which stores will have tents left over after 24 December, how many, and at what cost? The total, and
   the ten stores with the most."
4. `retail_analyst`: "Summit Tent return rate by batch."
5. `customer_feedback`: "Summit Tent pole or seam faults". Pick three comments and copy them word for word,
   with their date.

## 2. Build one JSON object

Keys, exactly as `render_report.py` expects:

- `report_date`: "4 Nov 2026"
- `headline`: one plain sentence on the biggest risk, from the numbers above. Name a state only for the
  figure that belongs to it.
- `kpis`: `tents_left_over` (total tents left over, all stores, from question 3), `b2607_return_rate_pct`
  (the B26-07 rate from question 4), `stores_running_out` (count of stores from question 2).
- `tent_sales`: `period` "1 to 3 November", `this_year_units`, `last_year_units`, `this_year_aud`,
  `last_year_aud`.
- `running_out`: rows of `store`, `state`, `tents_short`, `out_by`, most short first.
- `left_over`: rows of `store`, `state`, `tents_left_over`, `aud`, largest first (the ten from question 3).
- `return_rates`: rows of `batch`, `rate_pct`.
- `quotes`: three rows of `text`, `date`, `product`.
- `actions`: three short lines: send the broken B26-07 Summit Tents back to the supplier, move the spare tents
  to the stores running out, and reorder the rest by 13 November. Name the states.

## 3. Render it

Run `render_report.py` from this skill's folder in code execution, with the JSON as its input. It prints the
HTML. Do not change the HTML.

## 4. Send it

Call `send_report_email` once, with subject "Wilderness Christmas stock briefing, 4 Nov 2026" and the HTML the
script printed as `html_body`. It sends only to the person asking.

## 5. Reply

Three lines: the headline, the three tile values, and what `send_report_email` returned.

## Rules

- Every number must come from a tool result in this run. Never estimate or round up a missing number.
- Never invent or reword a quote.
- If a question returns nothing, leave that key out; the report shows "no data".
- Plain Australian English, short sentences, no marketing words, no exclamation marks.
- Use `send_report_email` only in step 4 of this skill.
