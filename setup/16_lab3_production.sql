-- =====================================================================================
-- 16_lab3_production.sql  ·  Wilderness Outfitters workshop
-- The production copy Lab 3 starts from: the assistant as Lab 1 builds it, with its own
-- search service and semantic view, and the eight evaluation questions. Everything goes into
-- WILDERNESS_HOL.LAB3_PRODUCTION, so Lab 3 does not depend on how far anyone got in Labs 1 and 2.
-- It is not added to CoWork here: Lab 3 Step 6 does that when it promotes a tested version.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WILDERNESS_WH;

-- The customer feedback search (about a minute to index 20,000 comments)
CREATE OR REPLACE CORTEX SEARCH SERVICE WILDERNESS_HOL.LAB3_PRODUCTION.CSS_CUSTOMER_FEEDBACK
  ON FEEDBACK_TEXT
  ATTRIBUTES PRODUCT_NAME, CATEGORY, FEEDBACK_SOURCE, STATE, RATING
  WAREHOUSE = WILDERNESS_WH
  TARGET_LAG = '1 day'
  COMMENT = 'Wilderness customer reviews, returns comments and survey answers'
AS
SELECT FEEDBACK_ID, FEEDBACK_DATE, FEEDBACK_SOURCE, PRODUCT_ID, PRODUCT_NAME, CATEGORY, BATCH_CODE,
       STORE_ID, STATE, RATING, FEEDBACK_TITLE, FEEDBACK_TEXT
FROM WILDERNESS_HOL.RAW.CUSTOMER_FEEDBACK;

-- The semantic view with the Lab 1 Step 3 additions
CREATE OR REPLACE SEMANTIC VIEW WILDERNESS_HOL.LAB3_PRODUCTION.SV_WILDERNESS_RETAIL
  TABLES (
    sales AS WILDERNESS_HOL.RAW.V_SALES PRIMARY KEY (SALE_LINE_ID)
      COMMENT = 'Sales lines, 1 Jul 2024 to 3 Nov 2026',
    returns AS WILDERNESS_HOL.RAW.V_RETURNS PRIMARY KEY (RETURN_ID)
      COMMENT = 'Customer returns, each linked to the sales line it came from',
    inventory AS WILDERNESS_HOL.RAW.V_INVENTORY PRIMARY KEY (INVENTORY_KEY)
      COMMENT = 'Stock on hand and on order at 3 Nov 2026, by store, product and batch',
    kit_cover AS WILDERNESS_HOL.RAW.V_KIT_COVER PRIMARY KEY (KIT_COVER_KEY)
      COMMENT = 'Sleeping, cooking and lighting kit needed for the tents still to sell before 24 Dec, by store',
    stock_cover AS WILDERNESS_HOL.RAW.V_STOCK_COVER PRIMARY KEY (STOCK_COVER_KEY)
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
    products.category AS CATEGORY WITH SYNONYMS = ('tent') COMMENT = 'Product category, for example Tents & Shelters',
    products.kit_group AS KIT_GROUP WITH SYNONYMS = ('sleeping gear') COMMENT = 'SHELTER, SLEEP, COOK, LIGHT or FURNITURE; null for other products',
    products.brand AS BRAND,
    products.in_christmas_catalogue AS IN_CHRISTMAS_CATALOGUE WITH SYNONYMS = ('Christmas range') COMMENT = 'TRUE for products in the Christmas catalogue',
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
    kit_cover.kit_cover_group AS KIT_GROUP WITH SYNONYMS = ('sleeping gear') COMMENT = 'SLEEP, COOK or LIGHT',
    kit_cover.run_out_week AS RUN_OUT_WEEK COMMENT = 'Monday of the week the store runs out of this kit group',
    stock_cover.christmas_stock_status AS CHRISTMAS_STOCK_STATUS
      COMMENT = 'STOCKOUT: under 6.5 weeks of forecast cover, runs out before about 16 Dec. OVERSTOCK: over 7.5 weeks, stock left after Christmas Eve. OK otherwise'
  )
  METRICS (
    sales.total_net_sales AS SUM(sales.net_sales) COMMENT = 'Net sales in AUD after discounts',
    sales.total_units_sold AS SUM(sales.units_sold),
    sales.gross_margin AS SUM(sales.net_sales) - SUM(sales.cost) COMMENT = 'Net sales less cost, AUD',
    returns.total_refunds AS SUM(returns.refund) COMMENT = 'Refunds paid, AUD',
    returns.total_units_returned AS SUM(returns.units_returned) WITH SYNONYMS = ('returns'),
    inventory.avg_weeks_of_cover AS AVG(inventory.weeks_of_cover) WITH SYNONYMS = ('stock cover')
      COMMENT = 'Average weeks of cover at last Christmas weekly sales rate',
    kit_cover.total_kit_shortfall_units AS SUM(kit_cover.shortfall_units)
      COMMENT = 'Kit units short of what the tents still to sell will need',
    kit_cover.basket_sales_at_risk AS SUM(kit_cover.basket_at_risk) COMMENT = 'Kit sales at risk from the shortfall, AUD',
    stock_cover.total_excess_units_at_xmas AS SUM(stock_cover.excess_units)
      COMMENT = 'Units still on hand after Christmas Eve on overstocked rows',
    stock_cover.total_excess_cost_aud AS SUM(stock_cover.excess_cost)
      COMMENT = 'Cost of stock still on hand after Christmas Eve, AUD',
    stock_cover.total_shortfall_units_to_xmas AS SUM(stock_cover.shortfall_units_to_xmas)
      COMMENT = 'Units short of the Christmas forecast on stockout rows',
    return_rate AS DIV0(returns.total_units_returned, sales.total_units_sold)
      COMMENT = 'Units returned divided by units sold'
  )
  COMMENT = 'Wilderness Outfitters retail: sales, returns, stock and kit cover'
  AI_VERIFIED_QUERIES (
    return_rate_by_category AS (
      QUESTION 'What is the return rate by category?'
      SQL 'WITH sold AS (SELECT p.category, SUM(s.units_sold) AS units_sold FROM __sales AS s JOIN __products AS p ON s.sale_product_id = p.product_id GROUP BY p.category), back AS (SELECT p.category, SUM(r.units_returned) AS units_returned FROM __returns AS r JOIN __sales AS s ON r.return_sale_line_id = s.sale_line_id JOIN __products AS p ON s.sale_product_id = p.product_id GROUP BY p.category) SELECT sold.category, sold.units_sold, COALESCE(back.units_returned, 0) AS units_returned, ROUND(COALESCE(back.units_returned, 0) / NULLIF(sold.units_sold, 0), 4) AS return_rate FROM sold LEFT JOIN back ON back.category = sold.category ORDER BY return_rate DESC NULLS LAST'
    ),
    sleeping_gear_shortfall_by_state AS (
      QUESTION 'Which states are short of sleeping gear, and by how much?'
      SQL 'SELECT st.state, COUNT(DISTINCT k.kit_cover_store_id) AS stores_short, SUM(k.shortfall_units) AS shortfall_units, SUM(k.basket_at_risk) AS basket_sales_at_risk_aud, MIN(k.run_out_week) AS earliest_run_out_week FROM __kit_cover AS k JOIN __stores AS st ON k.kit_cover_store_id = st.store_id WHERE k.kit_cover_group = ''SLEEP'' AND k.shortfall_units > 0 GROUP BY st.state ORDER BY shortfall_units DESC NULLS LAST'
    )
  )
  WITH TAG (WILDERNESS_HOL.SETUP.PROJECT = 'wilderness_christmas');

-- The Wilderness Assistant and its three tools
CREATE OR REPLACE AGENT WILDERNESS_HOL.LAB3_PRODUCTION.WILDERNESS_ASSISTANT
  COMMENT = 'Wilderness Outfitters Christmas trading assistant for store managers and merchandisers'
  PROFILE = '{"display_name": "Wilderness Assistant (production)"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: claude-sonnet-4-6
  instructions:
    response: >-
      You help Wilderness Outfitters store managers and merchandisers through Christmas trading.
      Use plain Australian English and short sentences. Give the answer first, then the numbers behind it.
      Show money in AUD. Quote customers and documents word for word and name the source.
      If the data does not cover the question, say so. Do not use marketing language.
    orchestration: >-
      Use retail_analyst for any number. Use customer_feedback for what customers said.
      For 'why' and 'what can we do' questions use more than one. Chart comparisons and trends.
    sample_questions:
      - question: "Tents are our big Christmas bet. Where will we still be holding tents on Boxing Day, where will we run out, and have we got the sleeping gear to go with them?"
      - question: "Customers are bringing the Summit 2P back. What are they saying, and is it worse for some batches than others?"
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "retail_analyst"
        description: >-
          Wilderness sales, returns and stock numbers. Sales lines from 1 Jul 2024 to 3 Nov 2026 with product,
          store, state and tent batch; returns linked to the sale they came from; stock on hand and on order at
          3 Nov 2026 by store, product and batch; Christmas stock cover per store and product against the
          forecast to 24 Dec, with overstock and stockout status; and the sleeping, cooking and lighting kit
          each store needs for the tents it still has to sell before 24 Dec. Use it for any count, total, rate,
          trend or comparison.
    - tool_spec:
        type: "cortex_search"
        name: "customer_feedback"
        description: >-
          20,000 customer comments from product reviews, returns desk notes and surveys, with the product,
          category, tent batch, store, state, rating and date. Use it to find and quote what customers said
          about a product, a fault or a request.
    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Charts the results of retail_analyst"
  tool_resources:
    retail_analyst:
      semantic_view: "WILDERNESS_HOL.LAB3_PRODUCTION.SV_WILDERNESS_RETAIL"
      execution_environment:
        type: "warehouse"
        warehouse: "WILDERNESS_WH"
        query_timeout: 60
    customer_feedback:
      search_service: "WILDERNESS_HOL.LAB3_PRODUCTION.CSS_CUSTOMER_FEEDBACK"
      id_column: "FEEDBACK_ID"
      title_column: "FEEDBACK_TITLE"
      max_results: 10
  $$;

-- Eight questions for the Lab 3 agent evaluation. Ground truth comes from this data, with fixed dates.
CREATE OR REPLACE TABLE WILDERNESS_HOL.LAB3_PRODUCTION.AGENT_EVAL_QUESTIONS (
  QUESTION_ID  INT,
  INPUT_QUERY  VARCHAR,
  GROUND_TRUTH VARIANT
);

INSERT INTO WILDERNESS_HOL.LAB3_PRODUCTION.AGENT_EVAL_QUESTIONS
SELECT $1, $2, PARSE_JSON($3) FROM VALUES
  (1, 'Which stores will still have too many tents on Boxing Day, and which will run out?',
      '{"ground_truth_output": "A correct answer covers both halves. Too many tents: the overstock is concentrated in Victoria and Tasmania, led by the Summit 2P Tent, where 14 stores hold more than 7.5 weeks of cover (about 1,909 units, AUD 553,164 at cost, left on Boxing Day). Counting other tent lines as well is acceptable if the answer still names Victoria and Tasmania. Run out: 11 stores, all in NSW, QLD, run out of the Summit 3P Tent before Christmas. An answer that misses either half, or puts the overstock outside Victoria and Tasmania, is wrong.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (2, 'Which stores will run out of sleeping gear before Christmas, and when?',
      '{"ground_truth_output": "31 stores will run short of sleeping gear before 24 December, 23 of them in NSW and QLD. Most run out in the week of 7 December (27 stores); the earliest week is 2026-11-30 and the latest 2026-12-14. The shortfall is about 3,837 units, AUD 435,673 of kit sales at risk.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (3, 'Customers are bringing the Summit 2P back. What are they saying, and is it worse for some batches than others?',
      '{"ground_truth_output": "Batch B26-07 is the problem: 17.2% of Summit 2P Tents sold from it have come back (702 of 4,087), against 3.5% to 4.0% for every other batch. Customers describe two faults: the pole snapping or cracking at the hub, and the seam tape lifting so the tent leaks in rain.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}, {"tool_name": "customer_feedback"}]}'),
  (4, 'What are customers saying about the Summit 2P tent?',
      '{"ground_truth_output": "Most Summit 2P comments are about faults: seams leaking in rain and poles cracking or snapping at the hub. Some customers praise how quick it is to pitch and how it does in dry weather. The answer quotes customers word for word.", "ground_truth_invocations": [{"tool_name": "customer_feedback"}]}'),
  (5, 'What were net sales over the launch weekend last year?',
      '{"ground_truth_output": "Over the launch weekend last year, 1 to 3 November 2025, net sales were AUD 5,955,928.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (6, 'What were net sales last financial year?',
      '{"ground_truth_output": "Net sales in the last financial year, FY26 (1 July 2025 to 30 June 2026), were AUD 378,017,732.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (7, 'How many tents did we sell over the launch weekend last year?',
      '{"ground_truth_output": "Wilderness sold 2,249 tents over the launch weekend last year, 1 to 3 November 2025.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (8, 'What''s the weather in Byron Bay on Christmas Day?',
      '{"ground_truth_output": "The agent says it has no weather data and does not guess. It offers to answer questions about Wilderness sales, stock, returns or customer feedback instead. It does not send the user to other websites or apps.", "ground_truth_invocations": []}');

-- The dataset the Evaluations tab picks in Lab 3 Step 2 (Existing dataset).
DROP DATASET IF EXISTS WILDERNESS_HOL.LAB3_PRODUCTION.CHRISTMAS_EVAL_SET;
CALL SYSTEM$CREATE_EVALUATION_DATASET(
  'Cortex Agent',
  'WILDERNESS_HOL.LAB3_PRODUCTION.AGENT_EVAL_QUESTIONS',
  'WILDERNESS_HOL.LAB3_PRODUCTION.CHRISTMAS_EVAL_SET',
  OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH'));

-- Where evaluation configuration files live (Lab 3 optional Step 10, and the build's own checks).
CREATE STAGE IF NOT EXISTS WILDERNESS_HOL.LAB3_PRODUCTION.EVAL_CONFIG
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Wilderness workshop: evaluation config files';

CALL WILDERNESS_HOL.SETUP.LOG_STEP('LAB3_PRODUCTION', 'OK',
  (SELECT COUNT(*) FROM WILDERNESS_HOL.LAB3_PRODUCTION.AGENT_EVAL_QUESTIONS));
