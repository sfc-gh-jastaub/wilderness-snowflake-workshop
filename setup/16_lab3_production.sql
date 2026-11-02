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
  ATTRIBUTES PRODUCT_NAME, CATEGORY, BATCH_CODE, STORE_ID, STATE, RATING, FEEDBACK_SOURCE
  WAREHOUSE = WILDERNESS_WH
  TARGET_LAG = '1 day'
  COMMENT = 'Wilderness product reviews, returns desk comments and contact-centre messages'
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
    products.category AS CATEGORY WITH SYNONYMS = ('tent', 'tents') COMMENT = 'Product category, for example Tents & Shelters',
    products.kit_group AS KIT_GROUP COMMENT = 'SHELTER, SLEEP, COOK, LIGHT or FURNITURE; null for other products',
    products.brand AS BRAND,
    products.in_christmas_catalogue AS IN_CHRISTMAS_CATALOGUE WITH SYNONYMS = ('Christmas range') COMMENT = 'TRUE for products in the Christmas catalogue',
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
    returns.total_units_returned AS SUM(returns.units_returned) WITH SYNONYMS = ('returns', 'tents returned'),
    inventory.avg_weeks_of_cover AS AVG(inventory.weeks_of_cover)
      COMMENT = 'Average weeks of cover at last Christmas weekly sales rate',
    tent_cover.total_tents_left_over AS SUM(tent_cover.tents_left_over) WITH SYNONYMS = ('left over', 'tents left over')
      COMMENT = 'Tents still on hand after Christmas Eve',
    tent_cover.total_tents_short AS SUM(tent_cover.tents_short) COMMENT = 'Tents short of the forecast to 24 Dec',
    tent_cover.total_left_over_cost AS SUM(tent_cover.left_over_cost) COMMENT = 'Cost of the tents still on hand after Christmas Eve, AUD',
    return_rate AS DIV0(returns.total_units_returned, sales.total_units_sold)
      COMMENT = 'Units returned divided by units sold'
  )
  COMMENT = 'Wilderness Outfitters retail: sales, returns, stock and tent cover by store'
  AI_VERIFIED_QUERIES (
    summit_tent_return_rate_by_batch AS (
      QUESTION 'What is the Summit Tent return rate by batch?'
      SQL 'WITH sold AS (SELECT s.sale_batch_code AS batch_code, SUM(s.units_sold) AS units_sold FROM __sales AS s JOIN __products AS p ON s.sale_product_id = p.product_id WHERE p.product_name = ''Summit Tent'' AND s.sale_batch_code IS NOT NULL GROUP BY s.sale_batch_code), back AS (SELECT s.sale_batch_code AS batch_code, SUM(r.units_returned) AS units_returned FROM __returns AS r JOIN __sales AS s ON r.return_sale_line_id = s.sale_line_id JOIN __products AS p ON s.sale_product_id = p.product_id WHERE p.product_name = ''Summit Tent'' GROUP BY s.sale_batch_code) SELECT sold.batch_code, sold.units_sold, COALESCE(back.units_returned, 0) AS units_returned, ROUND(COALESCE(back.units_returned, 0) / NULLIF(sold.units_sold, 0), 4) AS return_rate FROM sold LEFT JOIN back ON back.batch_code = sold.batch_code ORDER BY return_rate DESC NULLS LAST'
    ),
    stores_running_out_of_tents AS (
      QUESTION 'Which stores will run out of tents before Christmas?'
      SQL 'SELECT st.store_name, st.state, t.tents_on_hand, t.forecast_to_xmas, t.tents_short, t.run_out_date FROM __tent_cover AS t JOIN __stores AS st ON t.tent_cover_store_id = st.store_id WHERE t.status = ''RUNS OUT'' ORDER BY t.tents_short DESC NULLS LAST'
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
      - question: "What are customers saying about our tents?"
      - question: "Where will we run out of tents before Christmas, and where will we have tents left over?"
      - question: "What is the Summit Tent's return rate, and what do customers say when they bring one back?"
      - question: "Customers are bringing the Summit Tent back. What are they saying, and is one batch worse? Show the return rate by batch in a chart that makes the worst batch stand out."
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "retail_analyst"
        description: >-
          Wilderness sales, returns and stock numbers. Sales lines from 1 Jul 2024 to 3 Nov 2026 with product,
          store, state and tent batch; returns linked to the sale they came from; stock on hand at 3 Nov 2026
          by store, product and batch; and tent cover per store against the forecast to 24 Dec: which stores
          run out of tents and when, and which have tents left over. Use it for any count, total, rate, trend
          or comparison.
    - tool_spec:
        type: "cortex_search"
        name: "customer_feedback"
        description: >-
          20,000 customer comments from product reviews, returns desk notes and contact-centre messages, with the product,
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
  (1, 'What are customers saying about our tents?',
      '{"ground_truth_output": "Most tent comments are about the Summit Tent (853 of 1,856), and about half of those describe two faults: the pole cracking or snapping at the hub, and the seams leaking in rain, most of them from batch B26-07. Its average rating is 3.4 out of 5, against 3.9 for the other tents, which customers mostly rate well. The answer quotes customers word for word.", "ground_truth_invocations": [{"tool_name": "customer_feedback"}]}'),
  (2, 'Where will we run out of tents before Christmas, and where will we have tents left over?',
      '{"ground_truth_output": "33 stores, all in NSW and QLD, run out of tents before Christmas, around 18 December if the forecast holds, about 2,966 tents short. The other 39 stores, in ACT, SA, TAS, VIC, WA, will have about 5,212 tents left over after Christmas Eve. An answer that misses either half, or puts the shortfall outside NSW and QLD, is wrong.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (3, 'What is the Summit Tent''s return rate, and what do customers say when they bring one back?',
      '{"ground_truth_output": "The Summit Tent''s return rate is 5.1% across all batches. Batch B26-07 is worse: 18.1% of the Summit Tents sold from it have come back (655 of 3,620), against 3.0% to 4.1% for every other batch. Customers who bring one back describe two faults: the pole cracking or snapping at the hub, and the seams leaking in rain.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}, {"tool_name": "customer_feedback"}]}'),
  (4, 'Customers are bringing the Summit Tent back. What are they saying, and is one batch worse? Show the return rate by batch in a chart that makes the worst batch stand out.',
      '{"ground_truth_output": "Customers describe two faults: the pole cracking or snapping at the hub, and the seams leaking in rain. Batch B26-07 is worse: 18.1% of the Summit Tents sold from it have come back (655 of 3,620), against 3.0% to 4.1% for every other batch. The answer includes a chart of the return rate by batch.", "ground_truth_invocations": [{"tool_name": "customer_feedback"}, {"tool_name": "retail_analyst"}, {"tool_name": "data_to_chart"}]}'),
  (5, 'What were net sales over the launch weekend last year?',
      '{"ground_truth_output": "Over the launch weekend last year, 1 to 3 November 2025, net sales were AUD 5,457,940.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (6, 'What were net sales last financial year?',
      '{"ground_truth_output": "Net sales in the last financial year, FY26 (1 July 2025 to 30 June 2026), were AUD 351,478,452.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
  (7, 'How many tents did we sell over the launch weekend last year?',
      '{"ground_truth_output": "Wilderness sold 1,844 tents over the launch weekend last year, 1 to 3 November 2025.", "ground_truth_invocations": [{"tool_name": "retail_analyst"}]}'),
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
