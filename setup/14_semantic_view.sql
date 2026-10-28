-- =====================================================================================
-- 14_semantic_view.sql  ·  Wilderness Outfitters workshop
-- Four analytics views and the base semantic view SV_WILDERNESS_RETAIL.
-- The semantic view is deliberately incomplete: no return rate, no synonyms, no verified
-- queries and no custom instructions. Labs 1 and 3 add them.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WILDERNESS_WH;

CREATE OR REPLACE VIEW WILDERNESS_HOL.ANALYTICS.V_SALES
  COMMENT = 'One row per sales line, 1 Jul 2024 to 3 Nov 2026, with product and store attributes'
AS
SELECT f.SALE_LINE_ID, f.ORDER_ID, f.ORDER_DATE,
       f.STORE_ID, s.STORE_NAME, s.STATE, s.REGION_TYPE,
       f.PRODUCT_ID, p.PRODUCT_NAME, p.CATEGORY, p.SUBCATEGORY, p.KIT_GROUP, p.BRAND, p.IN_CHRISTMAS_CATALOGUE,
       f.BATCH_CODE, f.QUANTITY, f.UNIT_PRICE, f.DISCOUNT_AMOUNT, f.NET_SALES_AMOUNT, f.COST_AMOUNT
FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f
JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = f.PRODUCT_ID
JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = f.STORE_ID;

CREATE OR REPLACE VIEW WILDERNESS_HOL.ANALYTICS.V_RETURNS
  COMMENT = 'One row per return, each linked to its sales line, with product and store attributes'
AS
SELECT r.RETURN_ID, r.SALE_LINE_ID, f.ORDER_DATE, r.RETURN_DATE,
       r.STORE_ID, s.STORE_NAME, s.STATE, s.REGION_TYPE,
       r.PRODUCT_ID, p.PRODUCT_NAME, p.CATEGORY, p.SUBCATEGORY, p.KIT_GROUP, p.BRAND, p.IN_CHRISTMAS_CATALOGUE,
       r.BATCH_CODE, r.RETURN_QUANTITY, r.REFUND_AMOUNT, r.RETURN_REASON_CODE
FROM WILDERNESS_HOL.RAW.FCT_RETURN r
JOIN WILDERNESS_HOL.RAW.FCT_SALES_LINE f ON f.SALE_LINE_ID = r.SALE_LINE_ID
JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = r.PRODUCT_ID
JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = r.STORE_ID;

CREATE OR REPLACE VIEW WILDERNESS_HOL.ANALYTICS.V_INVENTORY
  COMMENT = 'Stock snapshot at 3 Nov 2026, one row per store, product and batch'
AS
SELECT i.STORE_ID || '|' || i.PRODUCT_ID || '|' || COALESCE(i.BATCH_CODE, '-') AS INVENTORY_KEY,
       i.SNAPSHOT_DATE, i.STORE_ID, s.STORE_NAME, s.STATE, s.REGION_TYPE,
       i.PRODUCT_ID, p.PRODUCT_NAME, p.CATEGORY, p.SUBCATEGORY, p.KIT_GROUP, p.BRAND, p.IN_CHRISTMAS_CATALOGUE,
       p.UNIT_COST, i.BATCH_CODE, i.ON_HAND_UNITS, i.ON_ORDER_UNITS, i.AVG_WEEKLY_UNITS_LY_XMAS, i.WEEKS_OF_COVER
FROM WILDERNESS_HOL.RAW.FCT_INVENTORY i
JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = i.PRODUCT_ID
JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = i.STORE_ID;

-- Kit cover per store and kit group (spec §4.5, S6). Tent forecast = last Christmas weekly tent
-- units x 51/7 x the state's tent index since 1 Nov; kit needed = forecast x last Christmas attach rate.
CREATE OR REPLACE VIEW WILDERNESS_HOL.ANALYTICS.V_KIT_COVER
  COMMENT = 'Sleeping, cooking and lighting kit needed for the tents still to sell before 24 Dec, per store'
AS
WITH tent_idx AS (
  SELECT s.STATE,
         SUM(IFF(f.ORDER_DATE BETWEEN '2026-11-01' AND '2026-11-03', f.QUANTITY, 0))
         / NULLIF(SUM(IFF(f.ORDER_DATE BETWEEN '2025-11-01' AND '2025-11-03', f.QUANTITY, 0)), 0) AS STATE_TENT_INDEX
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f
  JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = f.STORE_ID
  JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = f.PRODUCT_ID
  WHERE p.CATEGORY = 'Tents & Shelters'
    AND (f.ORDER_DATE BETWEEN '2025-11-01' AND '2025-11-03' OR f.ORDER_DATE BETWEEN '2026-11-01' AND '2026-11-03')
  GROUP BY 1),
tent_fc AS (
  SELECT i.STORE_ID, SUM(i.AVG_WEEKLY_UNITS_LY_XMAS) * 51 / 7 * COALESCE(MAX(t.STATE_TENT_INDEX), 1) AS TENT_FC
  FROM WILDERNESS_HOL.RAW.FCT_INVENTORY i
  JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = i.PRODUCT_ID
  JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = i.STORE_ID
  LEFT JOIN tent_idx t ON t.STATE = s.STATE
  WHERE p.CATEGORY = 'Tents & Shelters'
  GROUP BY 1),
kits AS (SELECT * FROM VALUES ('SLEEP'), ('COOK'), ('LIGHT') AS v(KIT_GROUP)),
tent_orders AS (
  SELECT f.STORE_ID, f.ORDER_ID,
         MAX(IFF(p.CATEGORY = 'Tents & Shelters', 1, 0)) AS HAS_TENT,
         MAX(IFF(p.KIT_GROUP = 'SLEEP', 1, 0)) AS HAS_SLEEP,
         MAX(IFF(p.KIT_GROUP = 'COOK', 1, 0)) AS HAS_COOK,
         MAX(IFF(p.KIT_GROUP = 'LIGHT', 1, 0)) AS HAS_LIGHT
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f
  JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = f.PRODUCT_ID
  WHERE f.ORDER_DATE BETWEEN '2025-11-01' AND '2025-12-24' AND f.STORE_ID <> 'ONLINE'
  GROUP BY 1, 2),
attach AS (
  SELECT o.STORE_ID, k.KIT_GROUP,
         AVG(CASE k.KIT_GROUP WHEN 'SLEEP' THEN o.HAS_SLEEP WHEN 'COOK' THEN o.HAS_COOK ELSE o.HAS_LIGHT END) AS ATTACH_RATE_LY
  FROM tent_orders o CROSS JOIN kits k
  WHERE o.HAS_TENT = 1
  GROUP BY 1, 2),
stock AS (
  SELECT i.STORE_ID, p.KIT_GROUP, SUM(i.ON_HAND_UNITS) AS ON_HAND, SUM(i.ON_ORDER_UNITS) AS ON_ORDER
  FROM WILDERNESS_HOL.RAW.FCT_INVENTORY i
  JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = i.PRODUCT_ID
  WHERE p.KIT_GROUP IN ('SLEEP', 'COOK', 'LIGHT')
  GROUP BY 1, 2),
price AS (
  SELECT p.KIT_GROUP, SUM(f.NET_SALES_AMOUNT) / SUM(f.QUANTITY) AS NET_PER_UNIT_LY
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f
  JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = f.PRODUCT_ID
  WHERE p.KIT_GROUP IN ('SLEEP', 'COOK', 'LIGHT') AND f.ORDER_DATE BETWEEN '2025-11-01' AND '2025-12-24'
  GROUP BY 1),
k AS (
  SELECT s.STORE_ID, s.STORE_NAME, s.STATE, a.KIT_GROUP, t.TENT_FC, a.ATTACH_RATE_LY,
         t.TENT_FC * a.ATTACH_RATE_LY AS NEEDED, st.ON_HAND, st.ON_ORDER, pr.NET_PER_UNIT_LY
  FROM WILDERNESS_HOL.RAW.DIM_STORE s
  JOIN tent_fc t ON t.STORE_ID = s.STORE_ID
  JOIN attach a ON a.STORE_ID = s.STORE_ID
  JOIN stock st ON st.STORE_ID = s.STORE_ID AND st.KIT_GROUP = a.KIT_GROUP
  JOIN price pr ON pr.KIT_GROUP = a.KIT_GROUP
  WHERE s.STORE_ID <> 'ONLINE')
SELECT
  STORE_ID || '|' || KIT_GROUP AS KIT_COVER_KEY,
  STORE_ID, STORE_NAME, STATE, KIT_GROUP,
  ROUND(TENT_FC, 1) AS TENT_FORECAST_UNITS_TO_XMAS,
  ROUND(ATTACH_RATE_LY, 4) AS ATTACH_RATE_LY,
  ROUND(NEEDED, 1) AS KIT_UNITS_NEEDED,
  ON_HAND AS KIT_ON_HAND_UNITS,
  ON_ORDER AS KIT_ON_ORDER_UNITS,
  ROUND(GREATEST(0, NEEDED - ON_HAND - ON_ORDER), 0) AS KIT_SHORTFALL_UNITS,
  IFF(NEEDED > ON_HAND + ON_ORDER,
      DATEADD(day, 1 - DAYOFWEEKISO(DATEADD(day, FLOOR((ON_HAND + ON_ORDER) / (NEEDED / 51)), '2026-11-04'::DATE)),
              DATEADD(day, FLOOR((ON_HAND + ON_ORDER) / (NEEDED / 51)), '2026-11-04'::DATE)),
      NULL) AS RUN_OUT_WEEK,
  ROUND(GREATEST(0, NEEDED - ON_HAND - ON_ORDER) * NET_PER_UNIT_LY, 2) AS BASKET_SALES_AT_RISK_AUD
FROM k;

-- Christmas stock cover per store and Christmas-catalogue product (S18): stock plus orders at 3 Nov, all
-- batches, against the forecast to 24 Dec = last Christmas weekly rate x 51/7 x the trend since 1 Nov in
-- that state and category. Same scope and S16 band as Lab 2's V_CHRISTMAS_STOCK_RISK, which adds batch
-- faults and actions.
CREATE OR REPLACE VIEW WILDERNESS_HOL.ANALYTICS.V_STOCK_COVER
  COMMENT = 'Christmas stock cover per store and Christmas-catalogue product at 3 Nov 2026, against the forecast to 24 Dec'
AS
WITH idx AS (
  SELECT s.STATE, p.CATEGORY,
         SUM(IFF(f.ORDER_DATE BETWEEN '2026-11-01' AND '2026-11-03', f.QUANTITY, 0))
         / NULLIF(SUM(IFF(f.ORDER_DATE BETWEEN '2025-11-01' AND '2025-11-03', f.QUANTITY, 0)), 0) AS IDX
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f
  JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = f.STORE_ID
  JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = f.PRODUCT_ID
  WHERE f.ORDER_DATE BETWEEN '2025-11-01' AND '2025-11-03' OR f.ORDER_DATE BETWEEN '2026-11-01' AND '2026-11-03'
  GROUP BY 1, 2),
inv AS (
  SELECT i.STORE_ID, i.PRODUCT_ID, MAX(p.UNIT_COST) AS UNIT_COST,
         SUM(i.ON_HAND_UNITS + i.ON_ORDER_UNITS) AS STOCK,
         SUM(i.AVG_WEEKLY_UNITS_LY_XMAS) * COALESCE(MAX(x.IDX), 1) AS WEEKLY_FC
  FROM WILDERNESS_HOL.RAW.FCT_INVENTORY i
  JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = i.STORE_ID
  JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = i.PRODUCT_ID
  LEFT JOIN idx x ON x.STATE = s.STATE AND x.CATEGORY = p.CATEGORY
  WHERE i.STORE_ID <> 'ONLINE' AND p.IN_CHRISTMAS_CATALOGUE
  GROUP BY 1, 2),
c AS (SELECT inv.*, WEEKLY_FC * 51 / 7 AS FC, STOCK / NULLIF(WEEKLY_FC, 0) AS COVER FROM inv)
SELECT STORE_ID || '|' || PRODUCT_ID AS STOCK_COVER_KEY, STORE_ID, PRODUCT_ID,
       STOCK AS STOCK_UNITS,
       ROUND(WEEKLY_FC, 2) AS WEEKLY_FORECAST_UNITS,
       ROUND(FC, 1) AS FORECAST_UNITS_TO_XMAS,
       ROUND(COVER, 2) AS FORECAST_WEEKS_OF_COVER,
       CASE WHEN COVER < 6.5 THEN 'STOCKOUT' WHEN COVER > 7.5 THEN 'OVERSTOCK' ELSE 'OK' END AS CHRISTMAS_STOCK_STATUS,
       IFF(COVER > 7.5, GREATEST(0, ROUND(STOCK - FC)), 0) AS EXCESS_UNITS_AT_XMAS,
       IFF(COVER < 6.5, GREATEST(0, ROUND(FC - STOCK)), 0) AS SHORTFALL_UNITS_TO_XMAS,
       ROUND(IFF(COVER > 7.5, GREATEST(0, ROUND(STOCK - FC)), 0) * UNIT_COST, 2) AS EXCESS_COST_AUD
FROM c;

-- The base semantic view. What it lacks is the point of Lab 1 Step 3 and Lab 3 Step 4.
CREATE OR REPLACE SEMANTIC VIEW WILDERNESS_HOL.ANALYTICS.SV_WILDERNESS_RETAIL
  TABLES (
    sales AS WILDERNESS_HOL.ANALYTICS.V_SALES PRIMARY KEY (SALE_LINE_ID)
      COMMENT = 'Sales lines, 1 Jul 2024 to 3 Nov 2026',
    returns AS WILDERNESS_HOL.ANALYTICS.V_RETURNS PRIMARY KEY (RETURN_ID)
      COMMENT = 'Customer returns, each linked to the sales line it came from',
    inventory AS WILDERNESS_HOL.ANALYTICS.V_INVENTORY PRIMARY KEY (INVENTORY_KEY)
      COMMENT = 'Stock on hand and on order at 3 Nov 2026, by store, product and batch',
    kit_cover AS WILDERNESS_HOL.ANALYTICS.V_KIT_COVER PRIMARY KEY (KIT_COVER_KEY)
      COMMENT = 'Sleeping, cooking and lighting kit needed for the tents still to sell before 24 Dec, by store',
    stock_cover AS WILDERNESS_HOL.ANALYTICS.V_STOCK_COVER PRIMARY KEY (STOCK_COVER_KEY)
      COMMENT = 'Christmas stock cover per store and product: stock plus orders at 3 Nov against the forecast to 24 Dec (last Christmas weekly rate x the trend since 1 Nov in that state and category). Use for overstock and stockout questions',
    products AS WILDERNESS_HOL.RAW.DIM_PRODUCT PRIMARY KEY (PRODUCT_ID)
      COMMENT = 'Product catalogue',
    stores AS WILDERNESS_HOL.RAW.DIM_STORE PRIMARY KEY (STORE_ID)
      COMMENT = '72 stores and the online store'
  )
  RELATIONSHIPS (
    sales_to_products AS sales (PRODUCT_ID) REFERENCES products,
    sales_to_stores AS sales (STORE_ID) REFERENCES stores,
    returns_to_sales AS returns (SALE_LINE_ID) REFERENCES sales,
    inventory_to_products AS inventory (PRODUCT_ID) REFERENCES products,
    inventory_to_stores AS inventory (STORE_ID) REFERENCES stores,
    kit_cover_to_stores AS kit_cover (STORE_ID) REFERENCES stores,
    stock_cover_to_products AS stock_cover (PRODUCT_ID) REFERENCES products,
    stock_cover_to_stores AS stock_cover (STORE_ID) REFERENCES stores
  )
  FACTS (
    sales.net_sales AS NET_SALES_AMOUNT,
    sales.units_sold AS QUANTITY,
    sales.cost AS COST_AMOUNT,
    returns.refund AS REFUND_AMOUNT,
    returns.units_returned AS RETURN_QUANTITY,
    inventory.weeks_of_cover AS WEEKS_OF_COVER,
    kit_cover.shortfall_units AS KIT_SHORTFALL_UNITS,
    kit_cover.basket_at_risk AS BASKET_SALES_AT_RISK_AUD,
    stock_cover.stock_units AS STOCK_UNITS,
    stock_cover.forecast_units_to_xmas AS FORECAST_UNITS_TO_XMAS,
    stock_cover.forecast_weeks_of_cover AS FORECAST_WEEKS_OF_COVER,
    stock_cover.excess_units AS EXCESS_UNITS_AT_XMAS,
    stock_cover.shortfall_units_to_xmas AS SHORTFALL_UNITS_TO_XMAS,
    stock_cover.excess_cost AS EXCESS_COST_AUD
  )
  DIMENSIONS (
    products.product_id AS PRODUCT_ID COMMENT = 'Product code, for example SKU-TNT-0102',
    products.product_name AS PRODUCT_NAME COMMENT = 'Product name',
    products.category AS CATEGORY COMMENT = 'Product category, for example Tents & Shelters',
    products.kit_group AS KIT_GROUP COMMENT = 'SHELTER, SLEEP, COOK, LIGHT or FURNITURE; null for other products',
    products.brand AS BRAND,
    products.in_christmas_catalogue AS IN_CHRISTMAS_CATALOGUE COMMENT = 'TRUE for products in the Christmas catalogue',
    stores.store_id AS STORE_ID COMMENT = 'Store code',
    stores.store_name AS STORE_NAME,
    stores.state AS STATE COMMENT = 'Australian state or territory; null for the online store',
    stores.region_type AS REGION_TYPE COMMENT = 'COASTAL, METRO, REGIONAL or ALPINE',
    sales.sale_line_id AS SALE_LINE_ID COMMENT = 'Sales line identifier',
    sales.sale_product_id AS PRODUCT_ID COMMENT = 'Product code on the sales line',
    sales.order_date AS ORDER_DATE COMMENT = 'Date of the sale',
    sales.sale_batch_code AS BATCH_CODE COMMENT = 'Tent production batch on the sales line',
    returns.return_sale_line_id AS SALE_LINE_ID COMMENT = 'Sales line the item was bought on',
    returns.return_date AS RETURN_DATE COMMENT = 'Date the item came back',
    returns.return_reason AS RETURN_REASON_CODE COMMENT = 'Reason code recorded by the store',
    returns.return_batch_code AS BATCH_CODE COMMENT = 'Tent production batch of the returned item',
    inventory.stock_batch_code AS BATCH_CODE COMMENT = 'Tent production batch held in stock',
    kit_cover.kit_cover_store_id AS STORE_ID COMMENT = 'Store code',
    kit_cover.kit_cover_group AS KIT_GROUP COMMENT = 'SLEEP, COOK or LIGHT',
    kit_cover.run_out_week AS RUN_OUT_WEEK COMMENT = 'Monday of the week the store runs out of this kit group',
    stock_cover.christmas_stock_status AS CHRISTMAS_STOCK_STATUS
      COMMENT = 'STOCKOUT: under 6.5 weeks of forecast cover, runs out before about 16 Dec. OVERSTOCK: over 7.5 weeks, stock left after Christmas Eve. OK otherwise'
  )
  METRICS (
    sales.total_net_sales AS SUM(sales.net_sales) COMMENT = 'Net sales in AUD after discounts',
    sales.total_units_sold AS SUM(sales.units_sold),
    sales.gross_margin AS SUM(sales.net_sales) - SUM(sales.cost) COMMENT = 'Net sales less cost, AUD',
    returns.total_refunds AS SUM(returns.refund) COMMENT = 'Refunds paid, AUD',
    returns.total_units_returned AS SUM(returns.units_returned),
    inventory.avg_weeks_of_cover AS AVG(inventory.weeks_of_cover)
      COMMENT = 'Average weeks of cover at last Christmas weekly sales rate',
    kit_cover.total_kit_shortfall_units AS SUM(kit_cover.shortfall_units)
      COMMENT = 'Kit units short of what the tents still to sell will need',
    kit_cover.basket_sales_at_risk AS SUM(kit_cover.basket_at_risk) COMMENT = 'Kit sales at risk from the shortfall, AUD',
    stock_cover.total_excess_units_at_xmas AS SUM(stock_cover.excess_units)
      COMMENT = 'Units still on hand after Christmas Eve on overstocked rows',
    stock_cover.total_excess_cost_aud AS SUM(stock_cover.excess_cost)
      COMMENT = 'Cost of stock still on hand after Christmas Eve, AUD',
    stock_cover.total_shortfall_units_to_xmas AS SUM(stock_cover.shortfall_units_to_xmas)
      COMMENT = 'Units short of the Christmas forecast on stockout rows'
  )
  COMMENT = 'Wilderness Outfitters retail: sales, returns, stock and kit cover'
  WITH TAG (WILDERNESS_HOL.GOVERNANCE.PROJECT = 'wilderness_christmas');

CALL WILDERNESS_HOL.GIT.LOG_STEP('SEMANTIC_VIEW', 'OK', NULL);
