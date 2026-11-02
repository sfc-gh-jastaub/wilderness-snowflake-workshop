import json

import altair as alt
import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

PLAN = "WILDERNESS_HOL.LAB2_ANALYTICS.CHRISTMAS_PLAN"
AGENT = "WILDERNESS_HOL.LAB1_ASSISTANT.WILDERNESS_ASSISTANT"
NUMERIC = ["LATITUDE", "LONGITUDE", "TENTS_ON_HAND", "TENTS_TO_SEND_BACK", "FORECAST_TO_XMAS", "GAP"]
# The same reds and greens as .streamlit/config.toml, so the map, chart and badges agree.
RED, GREEN = "#C0392B", "#2E7D46"

st.set_page_config(layout="wide")
session = get_active_session()

st.title("Christmas planner")
st.caption("Wilderness Outfitters, tents at 3 November 2026. Synthetic training data.")
with st.container(horizontal=True):
    st.badge("Stock at 3 Nov 2026", icon=":material/inventory_2:", color="gray")
    st.badge("B26-07 goes back to Kestrel", icon=":material/assignment_return:", color="red")
    st.badge("Reorder by 13 Nov", icon=":material/event:", color="orange")


@st.cache_data(ttl=600)
def load_plan():
    df = session.sql(f"SELECT * FROM {PLAN} ORDER BY STATE, STORE_NAME").to_pandas()
    for col in NUMERIC:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


plan = load_plan()

# The spare tents in MOVE OUT stores cover part of the shortfall in MOVE IN stores; the rest is
# reordered. Each short store gets the same share of the spare, so the tiles add up across states.
spare = plan.loc[plan["GAP"] > 0, "GAP"].sum()
short = -plan.loc[plan["GAP"] < 0, "GAP"].sum()
covered = min(1.0, spare / short) if short else 1.0
plan["MOVE_UNITS"] = plan["GAP"].where(plan["GAP"] > 0, -plan["GAP"] * covered)
plan["REORDER_UNITS"] = (-plan["GAP"] * (1 - covered)).where(plan["GAP"] < 0, 0)

states = ["All states"] + sorted(plan["STATE"].unique())
state = st.selectbox("State", states)
view = plan if state == "All states" else plan[plan["STATE"] == state]
scope = "all states" if state == "All states" else f"the state of {state}"


def ask_agent(question):
    # The request is built in Python and bound as one parameter, so the question never becomes SQL text.
    body = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": question}]}]})
    raw = session.sql(f"SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN('{AGENT}', ?)", params=[body]).collect()[0][0]
    return json.loads(raw)


def show_table(result_set):
    cols = [c["name"] for c in result_set["resultSetMetaData"]["rowType"]]
    df = pd.DataFrame(result_set["data"], columns=cols)
    for col in df.columns:
        # The result set sends every value as text; make a column numeric only if all of it converts.
        num = pd.to_numeric(df[col], errors="coerce")
        if num.notna().sum() == df[col].notna().sum():
            df[col] = num
    st.dataframe(df, hide_index=True)


def show_answer(answer):
    if "content" not in answer:
        # A missing agent comes back as an error object (code 399513), not as an exception.
        if answer.get("code") == "399513":
            st.warning(f"There is no Wilderness Assistant at {AGENT} yet. Build it in Lab 1, or run the Lab 1 catch-up.")
        else:
            st.error(f"The assistant could not answer: {answer.get('message', answer)}")
    for item in answer.get("content", []):
        if item.get("type") == "text" and item["text"].strip():
            st.markdown(item["text"])
        elif item.get("type") == "table":
            show_table(item["table"]["result_set"])
        elif item.get("type") == "chart":
            st.vega_lite_chart(spec=json.loads(item["chart"]["chart_spec"]), width="stretch")


with st.container(border=True):
    st.subheader("Ask the Wilderness Assistant")
    with st.form("ask_assistant", border=False):
        with st.container(horizontal=True, vertical_alignment="bottom"):
            question = st.text_input("Question", "Why are customers in this state bringing tents back?")
            asked = st.form_submit_button("Ask", icon=":material/send:", type="primary")
    if asked and question.strip():
        with st.spinner("The Wilderness Assistant is working on it. This takes 20 seconds to a minute."):
            try:
                answer = ask_agent(f"{question.strip()} Answer for {scope}.")
            except Exception as e:
                answer = {"message": str(e)}
        # Keep the answer, so changing the state filter afterwards does not wipe it.
        st.session_state["answer"] = (scope, answer)
    if "answer" in st.session_state:
        asked_scope, answer = st.session_state["answer"]
        with st.chat_message("assistant", avatar=":material/forest:"):
            st.caption(f"Answer for {asked_scope}")
            show_answer(answer)

moving_out = view.loc[view["GAP"] > 0, "MOVE_UNITS"].sum()
moving_in = view.loc[view["GAP"] < 0, "MOVE_UNITS"].sum()
if not moving_in:
    move, move_note = moving_out, "out of these stores"
elif not moving_out:
    move, move_note = moving_in, "into these stores"
else:
    # A tent that moves leaves one store and arrives at another: count it once.
    move, move_note = max(moving_out, moving_in), "from the other states to NSW and QLD"
n_short = int((view["GAP"] < 0).sum())

# Every tile has a grey note and no arrow, so the four cards line up.
with st.container(horizontal=True):
    st.metric("Tents to send back", f"{view['TENTS_TO_SEND_BACK'].sum():,.0f}", "faulty batch B26-07, to Kestrel",
              delta_color="off", delta_arrow="off", border=True)
    st.metric("Tents to move", f"{move:,.0f}", move_note, delta_color="off", delta_arrow="off", border=True)
    st.metric("Tents to reorder by 13 Nov", f"{view['REORDER_UNITS'].sum():,.0f}", "what the moves cannot cover",
              delta_color="off", delta_arrow="off", border=True)
    st.metric("Stores short", f"{n_short}", f"of {len(view)} stores", delta_color="off", delta_arrow="off",
              border=True)

action_colours = alt.Scale(domain=["MOVE IN", "MOVE OUT"], range=[RED, GREEN])
left, right = st.columns(2)
with left:
    with st.container(border=True):
        st.subheader("Stores")
        stores = view.assign(SIZE=view["GAP"].abs())
        store_map = alt.Chart(stores).mark_circle(opacity=0.85, stroke="white", strokeWidth=0.5).encode(
            longitude="LONGITUDE:Q",
            latitude="LATITUDE:Q",
            size=alt.Size("SIZE:Q", scale=alt.Scale(range=[40, 700]), legend=None),
            color=alt.Color("ACTION:N", scale=action_colours, legend=alt.Legend(orient="bottom", title=None)),
            tooltip=[alt.Tooltip("STORE_NAME:N", title="Store"), alt.Tooltip("STATE:N", title="State"),
                     alt.Tooltip("ACTION:N", title="Action"), alt.Tooltip("GAP:Q", title="Gap", format=",.0f")],
        ).project(type="mercator").properties(height=380)
        st.altair_chart(store_map, width="stretch")
with right:
    with st.container(border=True):
        st.subheader("Gap by state")
        by_state = plan.groupby("STATE", as_index=False)["GAP"].sum()
        by_state["ACTION"] = by_state["GAP"].map(lambda g: "MOVE OUT" if g > 0 else "MOVE IN")
        bars = alt.Chart(by_state).mark_bar(cornerRadiusEnd=4).encode(
            x=alt.X("STATE:N", sort="-y", title=None),
            y=alt.Y("GAP:Q", title="Good tents minus forecast"),
            color=alt.Color("ACTION:N", scale=action_colours, legend=None),
            # The chosen state stays bright; the others fade.
            opacity=alt.value(1) if state == "All states" else alt.condition(
                alt.datum.STATE == state, alt.value(1), alt.value(0.3)),
            tooltip=[alt.Tooltip("STATE:N", title="State"), alt.Tooltip("GAP:Q", title="Gap", format=",.0f")],
        ).properties(height=380)
        st.altair_chart(bars, width="stretch")

with st.container(border=True):
    st.subheader("Store plan, shortest first")
    st.dataframe(
        view.sort_values("GAP")[["STORE_NAME", "STATE", "TENTS_ON_HAND", "TENTS_TO_SEND_BACK", "FORECAST_TO_XMAS",
                                 "GAP", "ACTION", "MOVE_UNITS", "REORDER_UNITS"]],
        hide_index=True,
        column_config={
            "STORE_NAME": "Store", "STATE": "State",
            "TENTS_ON_HAND": st.column_config.NumberColumn("Tents on hand", format="localized"),
            "TENTS_TO_SEND_BACK": st.column_config.NumberColumn("Send back", format="localized"),
            "FORECAST_TO_XMAS": st.column_config.NumberColumn("Forecast to 24 Dec", format="localized"),
            "GAP": st.column_config.NumberColumn("Good tents minus forecast", format="localized"),
            "ACTION": "Action",
            "MOVE_UNITS": st.column_config.NumberColumn("Move", format="%d"),
            "REORDER_UNITS": st.column_config.NumberColumn("Reorder", format="%d"),
        },
    )
