-- =====================================================================================
-- 14_semantic_view.sql  ·  Wilderness Outfitters workshop
-- Four views over the raw data and the base semantic view SV_WILDERNESS_RETAIL.
-- The semantic view is deliberately incomplete: no return rate, no synonyms, no verified
-- queries and no custom instructions. Labs 1 and 3 add them.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WILDERNESS_WH;

CREATE OR REPLACE VIEW WILDERNESS_HOL.RAW.V_SALES
  COMMENT = 'One row per sales line, 1 Jul 2024 to 3 Nov 2026, with product and store attributes'
AS
SELECT f.SALE_LINE_ID, f.ORDER_ID, f.ORDER_DATE,
       f.STORE_ID, s.STORE_NAME, s.STATE, s.REGION_TYPE,
       f.PRODUCT_ID, p.PRODUCT_NAME, p.CATEGORY, p.SUBCATEGORY, p.KIT_GROUP, p.BRAND, p.IN_CHRISTMAS_CATALOGUE,
       f.BATCH_CODE, f.QUANTITY, f.UNIT_PRICE, f.DISCOUNT_AMOUNT, f.NET_SALES_AMOUNT, f.COST_AMOUNT
FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f
JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = f.PRODUCT_ID
JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = f.STORE_ID;

CREATE OR REPLACE VIEW WILDERNESS_HOL.RAW.V_RETURNS
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

CREATE OR REPLACE VIEW WILDERNESS_HOL.RAW.V_INVENTORY
  COMMENT = 'Stock snapshot at 3 Nov 2026, one row per store, product and batch'
AS
SELECT i.STORE_ID || '|' || i.PRODUCT_ID || '|' || COALESCE(i.BATCH_CODE, '-') AS INVENTORY_KEY,
       i.SNAPSHOT_DATE, i.STORE_ID, s.STORE_NAME, s.STATE, s.REGION_TYPE,
       i.PRODUCT_ID, p.PRODUCT_NAME, p.CATEGORY, p.SUBCATEGORY, p.KIT_GROUP, p.BRAND, p.IN_CHRISTMAS_CATALOGUE,
       p.UNIT_COST, i.BATCH_CODE, i.ON_HAND_UNITS, i.ON_ORDER_UNITS, i.AVG_WEEKLY_UNITS_LY_XMAS, i.WEEKS_OF_COVER
FROM WILDERNESS_HOL.RAW.FCT_INVENTORY i
JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = i.PRODUCT_ID
JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = i.STORE_ID;

-- Tent cover per store: every tent on the shelf at 3 Nov, faulty batch included, against the forecast
-- to 24 Dec. The forecast is the same as Lab 2's CHRISTMAS_PLAN: last year's 4 Nov-24 Dec tent sales
-- x the state's tent growth over 1-3 Nov. Lab 2 then takes the faulty B26-07 tents off first.
DROP VIEW IF EXISTS WILDERNESS_HOL.RAW.V_KIT_COVER;
DROP VIEW IF EXISTS WILDERNESS_HOL.RAW.V_STOCK_COVER;
CREATE OR REPLACE VIEW WILDERNESS_HOL.RAW.V_TENT_COVER
  COMMENT = 'Tent cover per store at 3 Nov 2026: tents on hand against the forecast to 24 Dec, and whether the store runs out or has tents left over'
AS
WITH tents AS (
  SELECT PRODUCT_ID, UNIT_COST FROM WILDERNESS_HOL.RAW.DIM_PRODUCT WHERE CATEGORY = 'Tents & Shelters'),
growth AS (
  SELECT s.STATE,
         SUM(IFF(f.ORDER_DATE BETWEEN '2026-11-01' AND '2026-11-03', f.QUANTITY, 0))
         / NULLIF(SUM(IFF(f.ORDER_DATE BETWEEN '2025-11-01' AND '2025-11-03', f.QUANTITY, 0)), 0) AS GROWTH
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f
  JOIN tents t ON t.PRODUCT_ID = f.PRODUCT_ID
  JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = f.STORE_ID
  WHERE f.ORDER_DATE BETWEEN '2025-11-01' AND '2025-11-03' OR f.ORDER_DATE BETWEEN '2026-11-01' AND '2026-11-03'
  GROUP BY 1),
last_year AS (
  SELECT f.STORE_ID, SUM(f.QUANTITY) AS TENTS_SOLD_LY
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f
  JOIN tents t ON t.PRODUCT_ID = f.PRODUCT_ID
  WHERE f.ORDER_DATE BETWEEN '2025-11-04' AND '2025-12-24'
  GROUP BY 1),
stock AS (
  SELECT i.STORE_ID, SUM(i.ON_HAND_UNITS) AS TENTS_ON_HAND,
         SUM(IFF(i.BATCH_CODE = 'B26-07', i.ON_HAND_UNITS, 0)) AS FAULTY_TENTS_ON_HAND,
         SUM(i.ON_HAND_UNITS * t.UNIT_COST) / NULLIF(SUM(i.ON_HAND_UNITS), 0) AS AVG_TENT_COST
  FROM WILDERNESS_HOL.RAW.FCT_INVENTORY i
  JOIN tents t ON t.PRODUCT_ID = i.PRODUCT_ID
  GROUP BY 1),
c AS (
  SELECT s.STORE_ID, s.STORE_NAME, s.STATE, st.TENTS_ON_HAND, st.FAULTY_TENTS_ON_HAND, st.AVG_TENT_COST,
         ROUND(ly.TENTS_SOLD_LY * g.GROWTH) AS FORECAST_TO_XMAS
  FROM WILDERNESS_HOL.RAW.DIM_STORE s
  JOIN stock st ON st.STORE_ID = s.STORE_ID
  JOIN last_year ly ON ly.STORE_ID = s.STORE_ID
  JOIN growth g ON g.STATE = s.STATE)
SELECT STORE_ID, STORE_NAME, STATE, TENTS_ON_HAND, FAULTY_TENTS_ON_HAND, FORECAST_TO_XMAS,
       GREATEST(0, TENTS_ON_HAND - FORECAST_TO_XMAS) AS TENTS_LEFT_OVER,
       GREATEST(0, FORECAST_TO_XMAS - TENTS_ON_HAND) AS TENTS_SHORT,
       IFF(TENTS_ON_HAND >= FORECAST_TO_XMAS, 'LEFT OVER', 'RUNS OUT') AS STATUS,
       -- 51 selling days from 4 Nov to 24 Dec; the day the tents on hand run out at the forecast rate
       IFF(TENTS_ON_HAND < FORECAST_TO_XMAS,
           DATEADD(day, FLOOR(TENTS_ON_HAND / (FORECAST_TO_XMAS / 51)), '2026-11-04'::DATE), NULL) AS RUN_OUT_DATE,
       ROUND(GREATEST(0, TENTS_ON_HAND - FORECAST_TO_XMAS) * AVG_TENT_COST, 2) AS LEFT_OVER_COST_AUD
FROM c;

-- The base semantic view. What it lacks is the point of Lab 1 Step 3 and Lab 3 Step 4.
CREATE OR REPLACE SEMANTIC VIEW WILDERNESS_HOL.LAB1_ASSISTANT.SV_WILDERNESS_RETAIL
  TABLES (
    sales AS WILDERNESS_HOL.RAW.V_SALES PRIMARY KEY (SALE_LINE_ID)
      COMMENT = 'Sales lines, 1 Jul 2024 to 3 Nov 2026',
    returns AS WILDERNESS_HOL.RAW.V_RETURNS PRIMARY KEY (RETURN_ID)
      COMMENT = 'Customer returns, each linked to the sales line it came from',
    inventory AS WILDERNESS_HOL.RAW.V_INVENTORY PRIMARY KEY (INVENTORY_KEY)
      COMMENT = 'Stock on hand and on order at 3 Nov 2026, by store, product and batch',
    tent_cover AS WILDERNESS_HOL.RAW.V_TENT_COVER PRIMARY KEY (STORE_ID)
      COMMENT = 'Tent cover per store at 3 Nov 2026: every tent on hand against the forecast to 24 Dec (last year''s 4 Nov-24 Dec tent sales x the state''s tent growth since 1 Nov). Use for where tents run out and where they are left over',
    products AS WILDERNESS_HOL.RAW.DIM_PRODUCT PRIMARY KEY (PRODUCT_ID)
      COMMENT = 'Product catalogue',
    stores AS WILDERNESS_HOL.RAW.DIM_STORE PRIMARY KEY (STORE_ID)
      COMMENT = '72 stores'
  )
  RELATIONSHIPS (
    sales_to_products AS sales (PRODUCT_ID) REFERENCES products,
    sales_to_stores AS sales (STORE_ID) REFERENCES stores,
    returns_to_sales AS returns (SALE_LINE_ID) REFERENCES sales,
    inventory_to_products AS inventory (PRODUCT_ID) REFERENCES products,
    inventory_to_stores AS inventory (STORE_ID) REFERENCES stores,
    tent_cover_to_stores AS tent_cover (STORE_ID) REFERENCES stores
  )
  FACTS (
    sales.net_sales AS NET_SALES_AMOUNT,
    sales.units_sold AS QUANTITY,
    sales.cost AS COST_AMOUNT,
    returns.refund AS REFUND_AMOUNT,
    returns.units_returned AS RETURN_QUANTITY,
    inventory.weeks_of_cover AS WEEKS_OF_COVER,
    tent_cover.tents_on_hand AS TENTS_ON_HAND,
    tent_cover.faulty_tents_on_hand AS FAULTY_TENTS_ON_HAND COMMENT = 'Tents on hand from the faulty Summit Tent batch B26-07',
    tent_cover.forecast_to_xmas AS FORECAST_TO_XMAS COMMENT = 'Tents the store is forecast to sell from 4 Nov to 24 Dec',
    tent_cover.tents_left_over AS TENTS_LEFT_OVER COMMENT = 'Tents still on hand after Christmas Eve',
    tent_cover.tents_short AS TENTS_SHORT COMMENT = 'Tents short of the forecast to 24 Dec',
    tent_cover.left_over_cost AS LEFT_OVER_COST_AUD
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
    stores.state AS STATE COMMENT = 'Australian state or territory',
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
    tent_cover.tent_cover_store_id AS STORE_ID COMMENT = 'Store code',
    tent_cover.status AS STATUS COMMENT = 'RUNS OUT: fewer tents on hand than the forecast to 24 Dec. LEFT OVER: tents still on hand after Christmas Eve',
    tent_cover.run_out_date AS RUN_OUT_DATE COMMENT = 'Day the store runs out of tents at the forecast rate; null if it has tents left over'
  )
  METRICS (
    sales.total_net_sales AS SUM(sales.net_sales) COMMENT = 'Net sales in AUD after discounts',
    sales.total_units_sold AS SUM(sales.units_sold),
    sales.gross_margin AS SUM(sales.net_sales) - SUM(sales.cost) COMMENT = 'Net sales less cost, AUD',
    returns.total_refunds AS SUM(returns.refund) COMMENT = 'Refunds paid, AUD',
    returns.total_units_returned AS SUM(returns.units_returned),
    inventory.avg_weeks_of_cover AS AVG(inventory.weeks_of_cover)
      COMMENT = 'Average weeks of cover at last Christmas weekly sales rate',
    tent_cover.total_tents_left_over AS SUM(tent_cover.tents_left_over)
      COMMENT = 'Tents still on hand after Christmas Eve',
    tent_cover.total_tents_short AS SUM(tent_cover.tents_short) COMMENT = 'Tents short of the forecast to 24 Dec',
    tent_cover.total_left_over_cost AS SUM(tent_cover.left_over_cost) COMMENT = 'Cost of the tents still on hand after Christmas Eve, AUD'
  )
  COMMENT = 'Wilderness Outfitters retail: sales, returns, stock and tent cover by store'
  WITH TAG (WILDERNESS_HOL.SETUP.PROJECT = 'wilderness_christmas');

CALL WILDERNESS_HOL.SETUP.LOG_STEP('SEMANTIC_VIEW', 'OK', NULL);
