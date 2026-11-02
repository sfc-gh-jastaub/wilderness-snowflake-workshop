import json

import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

PLAN = "WILDERNESS_HOL.LAB2_ANALYTICS.CHRISTMAS_PLAN"
AGENT = "WILDERNESS_HOL.LAB1_ASSISTANT.WILDERNESS_ASSISTANT"
NUMERIC = ["LATITUDE", "LONGITUDE", "TENTS_ON_HAND", "TENTS_TO_SEND_BACK", "FORECAST_TO_XMAS", "GAP"]

session = get_active_session()

st.title("Christmas planner")
st.caption("Wilderness Outfitters, tents at 3 November 2026. Synthetic training data.")


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


st.subheader("Ask the Wilderness Assistant")
with st.form("ask_assistant"):
    question = st.text_area("Question", "Why are customers in this state bringing tents back?")
    asked = st.form_submit_button("Ask")
if asked and question.strip():
    scope = "all states" if state == "All states" else f"the state of {state}"
    with st.spinner("The Wilderness Assistant is working on it..."):
        try:
            answer = ask_agent(f"{question.strip()} Answer for {scope}.")
        except Exception as e:
            answer = {"message": str(e)}
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
            st.vega_lite_chart(json.loads(item["chart"]["chart_spec"]), use_container_width=True)

moving_out = view.loc[view["GAP"] > 0, "MOVE_UNITS"].sum()
moving_in = view.loc[view["GAP"] < 0, "MOVE_UNITS"].sum()
if not moving_in:
    move, move_note = moving_out, "out of these stores"
elif not moving_out:
    move, move_note = moving_in, "into these stores"
else:
    # A tent that moves leaves one store and arrives at another: count it once.
    move, move_note = max(moving_out, moving_in), "from the other states to NSW and QLD"

c1, c2, c3 = st.columns(3)
c1.metric("Tents to send back", f"{view['TENTS_TO_SEND_BACK'].sum():,.0f}", "faulty batch B26-07, to Kestrel")
c2.metric("Tents to move", f"{move:,.0f}", move_note)
c3.metric("Tents to reorder by 13 Nov", f"{view['REORDER_UNITS'].sum():,.0f}", "what the moves cannot cover")

st.subheader("Stores")
st.dataframe(
    view[["STORE_NAME", "STATE", "TENTS_ON_HAND", "TENTS_TO_SEND_BACK", "FORECAST_TO_XMAS", "GAP", "ACTION",
          "MOVE_UNITS", "REORDER_UNITS"]],
    hide_index=True,
    column_config={
        "STORE_NAME": "Store", "STATE": "State", "TENTS_ON_HAND": "Tents on hand",
        "TENTS_TO_SEND_BACK": "Send back", "FORECAST_TO_XMAS": "Forecast to 24 Dec",
        "GAP": "Good tents minus forecast", "ACTION": "Action",
        "MOVE_UNITS": st.column_config.NumberColumn("Move", format="%d"),
        "REORDER_UNITS": st.column_config.NumberColumn("Reorder", format="%d"),
    },
)
