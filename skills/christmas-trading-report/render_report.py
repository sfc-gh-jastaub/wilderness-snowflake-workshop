"""Render the Wilderness Christmas stock briefing as one self-contained HTML page.

Standard library only. Reads one JSON object (a file path argument, or stdin) and prints the HTML.
Every value comes from the JSON: this script adds layout, never numbers. Missing data shows "no data".

  python3 render_report.py briefing.json > report.html

JSON keys (all optional except report_date):
  report_date      "4 Nov 2026"
  headline         one sentence
  kpis             {"tent_stock_at_risk_aud": 897732, "b2607_return_rate_pct": 17.2, "sleep_stores_short": 31}
  tent_sales       {"period": "1 to 3 November", "this_year_units": 3270, "last_year_units": 2249,
                    "this_year_aud": 7988070, "last_year_aud": 5955928}
  overstock        [{"store": "...", "state": "VIC", "excess_units": 214, "aud": 61931}]   (top rows)
  stockout         [{"store": "...", "state": "NSW", "product": "Summit 3P Tent", "out_by": "12 Dec"}]
  sleep_short      [{"store": "...", "state": "QLD", "short_from": "week of 7 Dec"}]
  return_rates     [{"batch": "B26-07", "rate_pct": 17.2}, {"batch": "B26-02", "rate_pct": 4.0}]
  quotes           [{"text": "...", "date": "2026-11-02", "product": "Summit 2P Tent"}]
  actions          ["Send B26-07 back to Kestrel", "..."]
"""
import html
import json
import sys

GREEN, SAND, INK, RUST, LINE = "#2d5a3d", "#f4efe6", "#1f2a24", "#b5562a", "#d9d2c3"


def esc(v):
    return html.escape(str(v), quote=True)


def num(v):
    if v is None or v == "":
        return "no data"
    if isinstance(v, (int, float)):
        return f"{v:,.0f}" if float(v).is_integer() or abs(v) >= 100 else f"{v:,.1f}"
    return esc(v)


def aud(v):
    return "no data" if v in (None, "") else (f"AUD {v:,.0f}" if isinstance(v, (int, float)) else esc(v))


def pct(v):
    return f"{v:.1f}" if isinstance(v, (int, float)) else num(v)


def pct_sign(v):
    return f"{v:.1f}%" if isinstance(v, (int, float)) else num(v)


def table(rows, cols):
    """cols: [(key, header, formatter)]. Up to 8 rows, to keep the email short."""
    if not rows:
        return '<p style="margin:4px 0;color:#666">no data</p>'
    head = "".join(f'<th style="text-align:left;padding:4px 8px;border-bottom:2px solid {GREEN}">{esc(h)}</th>'
                   for _, h, _ in cols)
    body = "".join("<tr>" + "".join(f'<td style="padding:4px 8px;border-bottom:1px solid {LINE}">{f(r.get(k))}</td>'
                                    for k, _, f in cols) + "</tr>" for r in rows[:8])
    more = f'<p style="margin:4px 0;color:#666;font-size:12px">and {len(rows) - 8} more</p>' if len(rows) > 8 else ""
    return f'<table style="border-collapse:collapse;width:100%;font-size:13px"><tr>{head}</tr>{body}</table>{more}'


def section(title, inner):
    return (f'<h2 style="font-size:16px;color:{GREEN};margin:20px 0 6px;border-bottom:1px solid {LINE};'
            f'padding-bottom:4px">{esc(title)}</h2>{inner}')


def tile(label, value):
    return (f'<td style="width:33%;padding:10px;background:{SAND};border:1px solid {LINE};vertical-align:top">'
            f'<div style="font-size:20px;font-weight:bold;color:{GREEN}">{value}</div>'
            f'<div style="font-size:12px;color:#555">{esc(label)}</div></td>')


def render(d):
    k = d.get("kpis") or {}
    ts = d.get("tent_sales") or {}
    tents = ""
    if ts:
        tents += (f'<p style="margin:4px 0">Tent sales, {esc(ts.get("period", "this period"))}: '
                  f'<b>{num(ts.get("this_year_units"))}</b> units ({aud(ts.get("this_year_aud"))}), against '
                  f'{num(ts.get("last_year_units"))} units ({aud(ts.get("last_year_aud"))}) on the same days last year.</p>')
    tents += '<p style="margin:8px 0 2px"><b>Too many tents</b></p>' + table(d.get("overstock"), [
        ("store", "Store", esc), ("state", "State", esc), ("excess_units", "Excess units", num), ("aud", "At cost", aud)])
    tents += '<p style="margin:8px 0 2px"><b>Running out</b></p>' + table(d.get("stockout"), [
        ("store", "Store", esc), ("state", "State", esc), ("product", "Product", esc), ("out_by", "Out by", esc)])
    kit = table(d.get("sleep_short"), [("store", "Store", esc), ("state", "State", esc), ("short_from", "Short from", esc)])
    kit += '<p style="margin:8px 0 2px"><b>Summit 2P return rate by batch</b></p>' + table(d.get("return_rates"), [
        ("batch", "Batch", esc), ("rate_pct", "Return rate %", pct)])
    quotes = "".join(f'<blockquote style="margin:6px 0;padding:6px 10px;border-left:3px solid {RUST};background:#fff">'
                     f'"{esc(q.get("text", ""))}"<br><span style="font-size:12px;color:#666">{esc(q.get("product", ""))}, '
                     f'{esc(q.get("date", ""))}</span></blockquote>' for q in (d.get("quotes") or [])[:3])
    actions = "".join(f"<li>{esc(a)}</li>" for a in (d.get("actions") or []))
    nodata = '<p style="margin:4px 0;color:#666">no data</p>'
    todo = f'<ol style="margin:4px 0 0 18px;padding:0">{actions}</ol>' if actions else nodata
    return (
        f'<!DOCTYPE html><html><head><meta charset="utf-8"><title>Wilderness Christmas stock briefing</title></head>'
        f'<body style="margin:0;background:#ffffff;font-family:Arial,Helvetica,sans-serif;color:{INK}">'
        f'<div style="max-width:680px;margin:0 auto;padding:16px">'
        f'<div style="background:{GREEN};color:#fff;padding:14px 16px">'
        f'<div style="font-size:12px;letter-spacing:1px">WILDERNESS OUTFITTERS · CHRISTMAS STOCK BRIEFING · {esc(d.get("report_date", ""))}</div>'
        f'<div style="font-size:18px;font-weight:bold;margin-top:6px">{esc(d.get("headline") or "no data")}</div></div>'
        f'<table style="width:100%;border-collapse:separate;border-spacing:6px;margin-top:8px"><tr>'
        f'{tile("Tent stock over what we will sell, at cost", aud(k.get("tent_stock_at_risk_aud")))}'
        f'{tile("Summit 2P batch B26-07 return rate", pct_sign(k.get("b2607_return_rate_pct")))}'
        f'{tile("Stores short of sleeping gear", num(k.get("sleep_stores_short")))}</tr></table>'
        f'{section("Tents", tents)}{section("The kit", kit)}'
        f'{section("What customers say", quotes or nodata)}{section("Do this week", todo)}'
        f'<p style="font-size:11px;color:#777;margin-top:24px;border-top:1px solid {LINE};padding-top:8px">'
        f'Generated by Wilderness Assistant from WILDERNESS_HOL. Synthetic training data.</p>'
        f'</div></body></html>')


if __name__ == "__main__":
    raw = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    out = render(json.loads(raw))
    with open("report.html", "w") as f:
        f.write(out)
    print(out)
