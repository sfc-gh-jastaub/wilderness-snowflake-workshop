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
2. `retail_analyst`: "For products in the category Tents & Shelters only, the excess units and excess at cost in
   AUD at 24 December: the total, the same by state, and the ten stores with the largest excess."
3. `retail_analyst`: "Which stores will run out of a tent before 24 December, which tent, and when?"
4. `retail_analyst`: "Which stores will run short of sleeping gear before 24 December, and from which week?"
5. `retail_analyst`: "Summit 2P Tent return rate by batch."
6. `customer_feedback`: "Summit 2P Tent pole or seam faults". Pick three comments and copy them word for word,
   with their date.

## 2. Build one JSON object

Keys, exactly as `render_report.py` expects:

- `report_date`: "4 Nov 2026"
- `headline`: one plain sentence on the biggest risk, from the numbers above. Name a state only for the
  figure that belongs to it.
- `kpis`: `tent_stock_at_risk_aud` (total excess at cost, all states, from question 2), `b2607_return_rate_pct`
  (the B26-07 rate from question 5), `sleep_stores_short` (count of stores from question 4).
- `tent_sales`: `period` "1 to 3 November", `this_year_units`, `last_year_units`, `this_year_aud`,
  `last_year_aud`.
- `overstock`: rows of `store`, `state`, `excess_units`, `aud`, largest first (the ten from question 2).
- `stockout`: rows of `store`, `state`, `product`, `out_by`.
- `sleep_short`: rows of `store`, `state`, `short_from`.
- `return_rates`: rows of `batch`, `rate_pct`.
- `quotes`: three rows of `text`, `date`, `product`.
- `actions`: three short lines: send the B26-07 tents back to the supplier, move tents from the overstocked
  stores to the stores running out, reorder sleeping gear for the stores that are short. Name the states.

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
