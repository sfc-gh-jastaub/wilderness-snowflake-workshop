import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import call_function, lit

VIEW = "WILDERNESS_HOL.ANALYTICS.V_CHRISTMAS_STOCK_RISK"
AUDIENCE = "WILDERNESS_HOL.ANALYTICS.KIT_OFFER_AUDIENCE"
MODEL = "claude-sonnet-4-6"
NUMERIC = ["LATITUDE", "LONGITUDE", "UNIT_COST", "ON_HAND_UNITS", "ON_ORDER_UNITS", "RETURNABLE_UNITS",
           "FORECAST_UNITS_TO_XMAS", "WEEKS_OF_COVER", "EST_DEFECT_RETURN_RATE", "EXCESS_UNITS",
           "SHORTFALL_UNITS", "STOCK_AT_RISK_AUD"]
# Tent orders on the launch weekend, and the Basecamp members who placed them.
FUNNEL_SQL = """
WITH o AS (
  SELECT f.ORDER_ID, f.MEMBER_ID, MAX(IFF(p.CATEGORY = 'Tents & Shelters', 1, 0)) AS HAS_TENT
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f
  JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = f.PRODUCT_ID
  WHERE f.ORDER_DATE BETWEEN '2026-11-01' AND '2026-11-03'
  GROUP BY 1, 2)
SELECT COUNT(*) AS TENT_ORDERS, COUNT(DISTINCT MEMBER_ID) AS TENT_MEMBERS
FROM o WHERE HAS_TENT = 1
"""

session = get_active_session()

st.title("Christmas planner")
st.caption("Wilderness Outfitters, 1 to 3 November 2026. Synthetic training data.")


@st.cache_data(ttl=600)
def load_plan():
    df = session.sql(f"SELECT * FROM {VIEW}").to_pandas()
    for col in NUMERIC:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


@st.cache_data(ttl=600)
def load_audience():
    return session.sql(f"SELECT * FROM {AUDIENCE} ORDER BY STATE, STORE_NAME, MEMBER_ID").to_pandas()


@st.cache_data(ttl=600)
def load_funnel():
    return session.sql(FUNNEL_SQL).to_pandas().iloc[0]


def write_email(member):
    """The same prompt as the notebook's kit_offer_email cell, for one member, on demand."""
    prompt = ("Write a short email from Wilderness Outfitters, an Australian outdoor retailer, to a Basecamp "
              f"loyalty member. They are {member['FIRST_NAME']}, who bought a {member['TENT_NAME']} at "
              f"{member['STORE_NAME']} this week but no sleeping bag or mat. Thank them, and offer 15% off a "
              f"sleeping bag or mat in store at {member['STORE_NAME']} before 24 December. Plain Australian "
              "English, under 80 words, no exclamation marks, no emoji. Return only a subject line and the body.")
    # lit() passes the prompt as a value, so the member's details never become SQL text.
    return (session.range(1)
            .select(call_function("AI_COMPLETE", lit(MODEL), lit(prompt)).cast("string").alias("EMAIL"))
            .collect()[0]["EMAIL"])


offer_tab, plan_tab = st.tabs(["Kit offer", "Stock plan"])

with offer_tab:
    audience = load_audience()
    funnel = load_funnel()
    offers = audience[audience["SEND_OFFER"]]

    st.subheader("From every tent sold to the members worth an offer")
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Tent orders", f"{int(funnel['TENT_ORDERS']):,}")
    c2.metric("Basecamp members", f"{int(funnel['TENT_MEMBERS']):,}")
    c3.metric("No sleeping gear", f"{len(audience):,}")
    c4.metric("Store has the kit", f"{len(offers):,}")
    st.caption("Members whose store is already short of sleeping gear are held back: "
               "an offer there would send customers in for stock that is not on the shelf.")

    st.subheader("Offers and held back, by state")
    by_state = (audience.assign(STATUS=audience["SEND_OFFER"].map({True: "Offer", False: "Held back"}))
                .groupby(["STATE", "STATUS"]).size().unstack(fill_value=0))
    st.bar_chart(by_state)

    st.subheader("The members who get an offer")
    states = ["All states"] + sorted(offers["STATE"].unique().tolist())
    state = st.selectbox("State", states)
    shown = offers if state == "All states" else offers[offers["STATE"] == state]
    st.dataframe(shown[["FIRST_NAME", "TIER", "TENT_NAME", "STORE_NAME", "STATE"]],
                 hide_index=True, use_container_width=True)

    st.subheader("Write one member's email")
    labels = {f"{r.FIRST_NAME}, {r.TENT_NAME}, {r.STORE_NAME} ({r.MEMBER_ID})": r.MEMBER_ID
              for r in shown.itertuples()}
    pick = st.selectbox("Member", list(labels))
    if pick and st.button("Write the email", type="primary"):
        member = shown[shown["MEMBER_ID"] == labels[pick]].iloc[0]
        with st.spinner("Writing the email with AI_COMPLETE"):
            st.session_state["email"] = (pick, write_email(member))
    if st.session_state.get("email") and st.session_state["email"][0] == pick:
        st.text_area("Email", st.session_state["email"][1], height=260)

with plan_tab:
    plan = load_plan()
    products = ["All products"] + sorted(plan["PRODUCT_NAME"].unique().tolist())
    choice = st.selectbox("Product", products)
    if choice != "All products":
        plan = plan[plan["PRODUCT_NAME"] == choice]

    returnable = plan.loc[plan["SUGGESTED_ACTION"] == "RETURN TO SUPPLIER", "RETURNABLE_UNITS"].sum()
    stockout_stores = plan.loc[plan["RISK"] == "STOCKOUT", "STORE_ID"].nunique()

    c1, c2, c3 = st.columns(3)
    c1.metric("Stock at risk on Boxing Day", f"AUD {plan['STOCK_AT_RISK_AUD'].sum():,.0f}")
    c2.metric("Units that can go back to the supplier", f"{int(returnable):,}")
    c3.metric("Stores that will run out", f"{stockout_stores}")

    st.subheader("Stock at risk by state")
    st.bar_chart(plan.groupby("STATE", dropna=True)["STOCK_AT_RISK_AUD"].sum().sort_values(ascending=False))

    st.subheader("Where the stock is")
    at_risk = plan[plan["RISK"] != "OK"].groupby(["STORE_NAME", "LATITUDE", "LONGITUDE"], as_index=False).agg(
        STOCK_AT_RISK_AUD=("STOCK_AT_RISK_AUD", "sum"))
    try:
        st.map(at_risk.rename(columns={"LATITUDE": "lat", "LONGITUDE": "lon"}))
    except Exception:
        st.caption("The map is not available here; the chart above shows the same picture by state.")

    st.subheader("What to do")
    actions = plan[plan["SUGGESTED_ACTION"] != "NONE"].sort_values(
        ["STOCK_AT_RISK_AUD", "SHORTFALL_UNITS"], ascending=False)
    st.dataframe(
        actions[["STORE_NAME", "STATE", "PRODUCT_NAME", "RISK", "EXCESS_UNITS", "SHORTFALL_UNITS",
                 "RETURNABLE_UNITS", "STOCK_AT_RISK_AUD", "SUGGESTED_ACTION"]],
        hide_index=True, use_container_width=True)
