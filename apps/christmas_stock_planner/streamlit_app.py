import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session

VIEW = "WILDERNESS_HOL.ANALYTICS.V_CHRISTMAS_STOCK_RISK"
NUMERIC = ["LATITUDE", "LONGITUDE", "UNIT_COST", "ON_HAND_UNITS", "ON_ORDER_UNITS", "RETURNABLE_UNITS",
           "FORECAST_UNITS_TO_XMAS", "WEEKS_OF_COVER", "EST_DEFECT_RETURN_RATE", "EXCESS_UNITS",
           "SHORTFALL_UNITS", "STOCK_AT_RISK_AUD"]

session = get_active_session()

st.title("Christmas stock planner")
st.caption("Wilderness Outfitters, stock at 3 November 2026. Synthetic training data.")


@st.cache_data(ttl=600)
def load_plan():
    df = session.sql(f"SELECT * FROM {VIEW}").to_pandas()
    for col in NUMERIC:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


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
by_state = (plan.groupby("STATE", dropna=True)["STOCK_AT_RISK_AUD"].sum()
            .sort_values(ascending=False))
st.bar_chart(by_state)

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
