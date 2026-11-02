-- =====================================================================================
-- 12_generate_structured.sql  ·  Wilderness Outfitters workshop
-- Stores, products, members, sales lines, returns and the 3 Nov 2026 stock snapshot.
--
-- Every value is derived from HASH(<row id>, '<salt>'), so every account gets exactly
-- the same rows. The window is 1 Jul 2024 to 3 Nov 2026; nothing reads today's date.
-- Background data is plain. Each story signal is set by its own labelled block, and the
-- numbers Lab 2 shows (1.4x tents everywhere, +60% / +10% demand) are exact by construction.
-- Helper tables live in SETUP as GEN_* and are dropped at the end.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WILDERNESS_WH;

-- -------------------------------------------------------------------------------------
-- 1. Stores: 72 stores in every state and territory except the NT; every order belongs to one
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE WILDERNESS_HOL.RAW.DIM_STORE (
  STORE_ID VARCHAR, STORE_NAME VARCHAR, STATE VARCHAR, REGION_TYPE VARCHAR,
  STORE_FORMAT VARCHAR, LATITUDE NUMBER(8,4), LONGITUDE NUMBER(8,4)
) AS SELECT * FROM VALUES
  ('S001','Wilderness Penrith','NSW','METRO','SUPERSTORE',-33.7510,150.6940),
  ('S002','Wilderness Parramatta','NSW','METRO','SUPERSTORE',-33.8150,151.0010),
  ('S003','Wilderness Castle Hill','NSW','METRO','SUPERSTORE',-33.7310,151.0040),
  ('S004','Wilderness Campbelltown','NSW','METRO','SUPERSTORE',-34.0650,150.8140),
  ('S005','Wilderness Liverpool','NSW','METRO','SUPERSTORE',-33.9200,150.9230),
  ('S006','Wilderness Brookvale','NSW','METRO','SUPERSTORE',-33.7660,151.2700),
  ('S007','Wilderness Alexandria','NSW','METRO','SUPERSTORE',-33.9040,151.1960),
  ('S008','Wilderness Newcastle','NSW','COASTAL','STANDARD',-32.9280,151.7810),
  ('S009','Wilderness Gosford','NSW','COASTAL','STANDARD',-33.4270,151.3420),
  ('S010','Wilderness Wollongong','NSW','COASTAL','STANDARD',-34.4250,150.8930),
  ('S011','Wilderness Port Macquarie','NSW','COASTAL','STANDARD',-31.4300,152.9090),
  ('S012','Wilderness Coffs Harbour','NSW','COASTAL','STANDARD',-30.2960,153.1140),
  ('S013','Wilderness Byron Bay','NSW','COASTAL','STANDARD',-28.6430,153.6150),
  ('S014','Wilderness Tweed Heads','NSW','COASTAL','STANDARD',-28.1760,153.5420),
  ('S015','Wilderness Nowra','NSW','COASTAL','STANDARD',-34.8810,150.6000),
  ('S016','Wilderness Batemans Bay','NSW','COASTAL','COMPACT',-35.7080,150.1750),
  ('S017','Wilderness Dubbo','NSW','REGIONAL','STANDARD',-32.2430,148.6040),
  ('S018','Wilderness Tamworth','NSW','REGIONAL','STANDARD',-31.0900,150.9290),
  ('S019','Wilderness Wagga Wagga','NSW','REGIONAL','STANDARD',-35.1180,147.3700),
  ('S020','Wilderness Jindabyne','NSW','ALPINE','COMPACT',-36.4160,148.6230),
  ('S021','Wilderness Ringwood','VIC','METRO','SUPERSTORE',-37.8140,145.2290),
  ('S022','Wilderness Moorabbin','VIC','METRO','SUPERSTORE',-37.9370,145.0580),
  ('S023','Wilderness Essendon','VIC','METRO','SUPERSTORE',-37.7520,144.9170),
  ('S024','Wilderness Dandenong','VIC','METRO','SUPERSTORE',-37.9870,145.2150),
  ('S025','Wilderness Preston','VIC','METRO','SUPERSTORE',-37.7420,145.0030),
  ('S026','Wilderness Werribee','VIC','METRO','SUPERSTORE',-37.9000,144.6610),
  ('S027','Wilderness Frankston','VIC','COASTAL','STANDARD',-38.1440,145.1260),
  ('S028','Wilderness Geelong','VIC','COASTAL','STANDARD',-38.1500,144.3610),
  ('S029','Wilderness Torquay','VIC','COASTAL','COMPACT',-38.3310,144.3260),
  ('S030','Wilderness Warrnambool','VIC','COASTAL','STANDARD',-38.3830,142.4820),
  ('S031','Wilderness Sale','VIC','REGIONAL','STANDARD',-38.1040,147.0680),
  ('S032','Wilderness Traralgon','VIC','REGIONAL','STANDARD',-38.1950,146.5410),
  ('S033','Wilderness Ballarat','VIC','REGIONAL','STANDARD',-37.5620,143.8500),
  ('S034','Wilderness Bendigo','VIC','REGIONAL','STANDARD',-36.7570,144.2790),
  ('S035','Wilderness Shepparton','VIC','REGIONAL','STANDARD',-36.3800,145.3990),
  ('S036','Wilderness Wodonga','VIC','REGIONAL','STANDARD',-36.1220,146.8880),
  ('S037','Wilderness Mildura','VIC','REGIONAL','STANDARD',-34.1860,142.1620),
  ('S038','Wilderness Bright','VIC','ALPINE','COMPACT',-36.7300,146.9600),
  ('S039','Wilderness Fortitude Valley','QLD','METRO','SUPERSTORE',-27.4570,153.0350),
  ('S040','Wilderness Chermside','QLD','METRO','SUPERSTORE',-27.3860,153.0300),
  ('S041','Wilderness Springwood','QLD','METRO','SUPERSTORE',-27.6110,153.1290),
  ('S042','Wilderness Indooroopilly','QLD','METRO','SUPERSTORE',-27.4990,152.9730),
  ('S043','Wilderness Southport','QLD','COASTAL','STANDARD',-27.9670,153.4000),
  ('S044','Wilderness Maroochydore','QLD','COASTAL','STANDARD',-26.6600,153.0990),
  ('S045','Wilderness Noosa','QLD','COASTAL','COMPACT',-26.3940,153.0900),
  ('S046','Wilderness Hervey Bay','QLD','COASTAL','STANDARD',-25.2900,152.8440),
  ('S047','Wilderness Mackay','QLD','COASTAL','STANDARD',-21.1440,149.1860),
  ('S048','Wilderness Townsville','QLD','COASTAL','STANDARD',-19.2590,146.8170),
  ('S049','Wilderness Cairns','QLD','COASTAL','STANDARD',-16.9190,145.7710),
  ('S050','Wilderness Rockhampton','QLD','REGIONAL','STANDARD',-23.3780,150.5100),
  ('S051','Wilderness Toowoomba','QLD','REGIONAL','STANDARD',-27.5600,151.9510),
  ('S052','Wilderness Osborne Park','WA','METRO','SUPERSTORE',-31.9010,115.8130),
  ('S053','Wilderness Cannington','WA','METRO','SUPERSTORE',-32.0170,115.9370),
  ('S054','Wilderness Joondalup','WA','METRO','SUPERSTORE',-31.7450,115.7660),
  ('S055','Wilderness Midland','WA','METRO','SUPERSTORE',-31.8880,116.0070),
  ('S056','Wilderness Mandurah','WA','COASTAL','STANDARD',-32.5270,115.7230),
  ('S057','Wilderness Bunbury','WA','COASTAL','STANDARD',-33.3270,115.6410),
  ('S058','Wilderness Busselton','WA','COASTAL','COMPACT',-33.6510,115.3460),
  ('S059','Wilderness Geraldton','WA','COASTAL','STANDARD',-28.7740,114.6150),
  ('S060','Wilderness Mile End','SA','METRO','SUPERSTORE',-34.9260,138.5740),
  ('S061','Wilderness Gepps Cross','SA','METRO','SUPERSTORE',-34.8400,138.6010),
  ('S062','Wilderness Noarlunga','SA','METRO','STANDARD',-35.1400,138.4960),
  ('S063','Wilderness Mount Barker','SA','REGIONAL','COMPACT',-35.0670,138.8590),
  ('S064','Wilderness Victor Harbor','SA','COASTAL','COMPACT',-35.5520,138.6180),
  ('S065','Wilderness Mount Gambier','SA','REGIONAL','STANDARD',-37.8290,140.7820),
  ('S066','Wilderness Hobart','TAS','METRO','STANDARD',-42.8820,147.3270),
  ('S067','Wilderness Launceston','TAS','REGIONAL','STANDARD',-41.4390,147.1340),
  ('S068','Wilderness Devonport','TAS','COASTAL','STANDARD',-41.1800,146.3460),
  ('S069','Wilderness Burnie','TAS','COASTAL','COMPACT',-41.0530,145.9060),
  ('S070','Wilderness Fyshwick','ACT','METRO','SUPERSTORE',-35.3280,149.1740),
  ('S071','Wilderness Belconnen','ACT','METRO','STANDARD',-35.2380,149.0660),
  ('S072','Wilderness Tuggeranong','ACT','METRO','STANDARD',-35.4190,149.0880);

-- -------------------------------------------------------------------------------------
-- 2. Products: 1,200 across 10 categories
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_CATEGORY AS
SELECT $1 AS CAT_ORD, $2 AS CATEGORY, $3 AS CODE, $4 AS N, $5 AS KIT_GROUP, $6 AS COST_LO, $7 AS COST_HI,
       $8 AS SUPPLIER_ID, $9 AS SUPPLIER_NAME, $10 AS W_GENERAL, $11 AS W_FILLER,
       SPLIT($12, '|') AS SUBS, SPLIT($13, '|') AS NOUNS
FROM VALUES
  (1,'Tents & Shelters','TNT',90,'SHELTER',90,600,'SUP-01','Kestrel Shelters',0,0,
     'Hiking Tents|Family Tents|Dome Tents|Touring Tents','Hiking Tent|Family Tent|Dome Tent|Touring Tent'),
  (2,'Sleeping','SLP',110,'SLEEP',18,80,'SUP-02','Dreamtrail Sleep Co',10,0,
     'Sleeping Bags|Sleeping Mats|Sleeping Bags|Sleeping Mats','Sleeping Bag|Sleeping Mat|Mummy Sleeping Bag|Self-Inflating Mat'),
  (3,'Camp Kitchen','CKN',130,'COOK',10,150,'SUP-03','Billycan Camp Kitchens',12,0,
     'Stoves|Cookware|Coolers|Water Storage','Stove|Cook Set|Cooler|Water Jerry'),
  (4,'Lighting & Power','LGT',90,'LIGHT',8,120,'SUP-04','Lumenwood Lighting',9,0,
     'Lanterns|Headlamps|Power Banks|Solar Panels','Lantern|Headlamp|Power Bank|Solar Panel'),
  (5,'Camp Furniture','FUR',100,'FURNITURE',20,200,'SUP-05','Campfold Furniture',10,10,
     'Chairs|Tables|Stretchers|Hammocks','Camp Chair|Camp Table|Stretcher|Hammock'),
  (6,'Hiking & Packs','HIK',120,NULL,15,180,'SUP-06','Ridgeway Packs',11,11,
     'Backpacks|Daypacks|Trekking Poles|Navigation','Backpack|Daypack|Trekking Pole|GPS Compass'),
  (7,'Clothing & Footwear','CLO',220,NULL,15,160,'SUP-08','Northgale Apparel',20,20,
     'Jackets|Fleece|Hiking Boots|Sandals','Rain Jacket|Fleece|Hiking Boot|Sandal'),
  (8,'Fishing','FSH',140,NULL,5,250,'SUP-09','Tackleshed Wholesale',14,14,
     'Rods|Reels|Tackle|Lures','Rod|Reel|Tackle Box|Lure Pack'),
  (9,'Water & Kayak','WTR',100,NULL,15,700,'SUP-10','Paddlecraft Imports',7,7,
     'Kayaks|Paddles|PFDs|Snorkelling','Kayak|Paddle|PFD|Snorkel Set'),
  (10,'Snow','SNW',100,NULL,20,250,'SUP-11','Snowline Distribution',7,7,
     'Snow Jackets|Snow Pants|Gloves|Goggles','Snow Jacket|Snow Pant|Snow Glove|Goggle');

CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_PRODUCT AS
WITH n AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS PN FROM TABLE(GENERATOR(ROWCOUNT => 1200))),
c AS (SELECT *, SUM(N) OVER (ORDER BY CAT_ORD) - N AS START_PN FROM WILDERNESS_HOL.SETUP.GEN_CATEGORY),
p AS (SELECT n.PN, c.*, n.PN - c.START_PN AS IDX
      FROM n JOIN c ON n.PN > c.START_PN AND n.PN <= c.START_PN + c.N),
w AS (
  SELECT p.*,
    SUBS[MOD(IDX - 1, 4)]::VARCHAR AS SUBCATEGORY,
    NOUNS[MOD(IDX - 1, 4)]::VARCHAR AS NOUN,
    ARRAY_CONSTRUCT('Ridge','Granite','Banksia','Coolabah','Tasman','Murray','Gorge','Saltbush',
                    'Wattle','Highland','Outback','Ironbark','Bluegum','Bramble','Mallee','Tidewater')
      [MOD(FLOOR((IDX - 1) / 4), 16)]::VARCHAR AS ADJ,
    ARRAY_CONSTRUCT('','Lite','Pro','Plus','Trek','Base','Max','Elite')
      [MOD(FLOOR((IDX - 1) / 64), 8)]::VARCHAR AS MODEL,
    MOD(ABS(HASH(PN, 'cost')), 1000000) / 1000000 AS U_COST,
    MOD(ABS(HASH(PN, 'markup')), 1000000) / 1000000 AS U_MARKUP,
    MOD(ABS(HASH(PN, 'brand')), 1000000) / 1000000 AS U_BRAND
  FROM p)
SELECT
  CAT_ORD, IDX,
  'SKU-' || CODE || '-' || LPAD(CAT_ORD * 100 + IDX, 4, '0') AS PRODUCT_ID,
  ADJ || ' ' || NOUN || IFF(MODEL = '', '', ' ' || MODEL) AS PRODUCT_NAME,
  CATEGORY, SUBCATEGORY, KIT_GROUP,
  IFF(U_BRAND < 0.4, 'Wilderness',
      ARRAY_CONSTRUCT('Bramblewood','Tarnfield','Quolla','Mallee & Co','Northgale','Wombat Ridge',
                      'Saltmarsh','Kestrel')[MOD(ABS(HASH(PN, 'brandname')), 8)]::VARCHAR) AS BRAND,
  IFF(SUBCATEGORY IN ('Hiking Boots','Sandals'), 'SUP-07', SUPPLIER_ID) AS SUPPLIER_ID,
  IFF(SUBCATEGORY IN ('Hiking Boots','Sandals'), 'Alpine Footwear Co', SUPPLIER_NAME) AS SUPPLIER_NAME,
  ROUND(COST_LO + U_COST * (COST_HI - COST_LO), 2) AS UNIT_COST,
  ROUND(ROUND(COST_LO + U_COST * (COST_HI - COST_LO), 2) * (2.0 + 0.4 * U_MARKUP)) - 0.01 AS RRP,
  (CAT_ORD = 1 AND IDX <= 20) OR (CAT_ORD = 2 AND (IDX <= 15 OR IDX = 110))
    OR (CAT_ORD IN (3, 4) AND IDX <= 10) OR (CAT_ORD = 5 AND IDX <= 5) AS IN_CHRISTMAS_CATALOGUE
FROM w;

-- SIGNAL: the four hero products
UPDATE WILDERNESS_HOL.SETUP.GEN_PRODUCT g
SET PRODUCT_NAME = h.NAME, SUBCATEGORY = h.SUB, BRAND = 'Wilderness',
    SUPPLIER_ID = h.SUP_ID, SUPPLIER_NAME = h.SUP_NAME, UNIT_COST = h.COST, RRP = h.RRP,
    IN_CHRISTMAS_CATALOGUE = TRUE
FROM (SELECT * FROM VALUES
  ('SKU-TNT-0102','Summit Tent','Hiking Tents','SUP-01','Kestrel Shelters',290.00,649.00),
  ('SKU-TNT-0103','Overland 3P Tent','Hiking Tents','SUP-01','Kestrel Shelters',380.00,849.00),
  ('SKU-SLP-0201','Trailhead Self-Inflating Mat','Sleeping Mats','SUP-02','Dreamtrail Sleep Co',45.00,119.00),
  ('SKU-SLP-0310','Coastline 2-Season Sleeping Bag','Sleeping Bags','SUP-02','Dreamtrail Sleep Co',55.00,149.00)
  AS v(PID, NAME, SUB, SUP_ID, SUP_NAME, COST, RRP)) h
WHERE g.PRODUCT_ID = h.PID;

CREATE OR REPLACE TABLE WILDERNESS_HOL.RAW.DIM_PRODUCT AS
SELECT PRODUCT_ID, PRODUCT_NAME, CATEGORY, SUBCATEGORY, KIT_GROUP, BRAND, SUPPLIER_ID, SUPPLIER_NAME,
       UNIT_COST::NUMBER(10,2) AS UNIT_COST, RRP::NUMBER(10,2) AS RRP, IN_CHRISTMAS_CATALOGUE
FROM WILDERNESS_HOL.SETUP.GEN_PRODUCT ORDER BY PRODUCT_ID;

-- -------------------------------------------------------------------------------------
-- 3. Members: 180,000, example.com addresses only
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE WILDERNESS_HOL.RAW.DIM_MEMBER
  COMMENT = 'Basecamp, the Wilderness loyalty programme: one row per member, with home store and tier'
AS
WITH n AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS MN FROM TABLE(GENERATOR(ROWCOUNT => 180000))),
s AS (SELECT STORE_ID, STATE, ROW_NUMBER() OVER (ORDER BY STORE_ID) AS SN
      FROM WILDERNESS_HOL.RAW.DIM_STORE),
m AS (
  SELECT MN,
    ARRAY_CONSTRUCT('Olivia','Jack','Charlotte','William','Amelia','Noah','Isla','Oliver','Mia','Thomas',
                    'Grace','James','Chloe','Lucas','Ava','Henry','Sophie','Ethan','Ruby','Liam',
                    'Zoe','Harry','Emily','Samuel','Matilda','Lachlan','Ella','Cooper','Lily','Riley')
      [MOD(ABS(HASH(MN, 'first')), 30)]::VARCHAR AS FIRST_NAME,
    ARRAY_CONSTRUCT('Smith','Jones','Williams','Brown','Wilson','Taylor','Nguyen','Johnson','Martin','White',
                    'Anderson','Walker','Thompson','Thomas','Lee','Ryan','Robinson','Kelly','King','Harris',
                    'Davis','Wright','Mitchell','Clarke','Campbell','Murphy','Hall','Young','Scott','Chen')
      [MOD(ABS(HASH(MN, 'last')), 30)]::VARCHAR AS LAST_NAME,
    1 + MOD(ABS(HASH(MN, 'home')), 72) AS SN,
    MOD(ABS(HASH(MN, 'postcode')), 1000) AS H_PC,
    MOD(ABS(HASH(MN, 'tier')), 100) AS H_TIER
  FROM n)
SELECT
  'M' || LPAD(MN, 6, '0') AS MEMBER_ID, FIRST_NAME, LAST_NAME,
  LOWER(FIRST_NAME || '.' || LAST_NAME || MN || '@example.com') AS EMAIL,
  (CASE s.STATE WHEN 'NSW' THEN 2000 + MOD(H_PC, 600) WHEN 'ACT' THEN 2600 + MOD(H_PC, 20)
                WHEN 'VIC' THEN 3000 + MOD(H_PC, 900) WHEN 'QLD' THEN 4000 + MOD(H_PC, 800)
                WHEN 'SA' THEN 5000 + MOD(H_PC, 700) WHEN 'WA' THEN 6000 + MOD(H_PC, 700)
                ELSE 7000 + MOD(H_PC, 300) END)::VARCHAR AS POSTCODE,
  s.STORE_ID AS HOME_STORE_ID,
  CASE WHEN H_TIER < 10 THEN 'Gold' WHEN H_TIER < 30 THEN 'Silver' ELSE 'Standard' END AS TIER
FROM m JOIN s ON s.SN = m.SN
ORDER BY MEMBER_ID;

-- -------------------------------------------------------------------------------------
-- 4. Orders, one store-day at a time: about 1.2 million
-- -------------------------------------------------------------------------------------
-- Orders per store per day = 12 x store size x season x growth, +/-15% noise.
-- Store size: superstore 1.4, standard 1.0, compact 0.7.
-- Season: Christmas period 1 Nov - 24 Dec x2.2, Boxing Day week x1.8, Easter week x1.4,
-- Christmas Day x0.3, and 15% a year growth.
-- A tent order is 3 or 4 lines: 25% of orders in the Christmas period, 10% otherwise.
-- The launch weekend 2026 (1-3 Nov) gets no tent orders here; section 5 adds them.
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_NUM AS
SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS K FROM TABLE(GENERATOR(ROWCOUNT => 1000));

CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_ORDER_SRC AS
WITH d AS (SELECT DATEADD(day, K, '2024-07-01'::DATE) AS D FROM WILDERNESS_HOL.SETUP.GEN_NUM WHERE K < 856),
dw AS (
  SELECT D,
    (CASE
       WHEN MONTH(D) = 12 AND DAY(D) = 25 THEN 0.3
       WHEN MONTH(D) = 11 OR (MONTH(D) = 12 AND DAY(D) <= 24) THEN 2.2
       WHEN (MONTH(D) = 12 AND DAY(D) >= 26) OR (MONTH(D) = 1 AND DAY(D) = 1) THEN 1.8
       WHEN D BETWEEN '2025-04-14' AND '2025-04-21' OR D BETWEEN '2026-03-30' AND '2026-04-06' THEN 1.4
       ELSE 1.0 END) * (1 + 0.15 * DATEDIFF(day, '2024-07-01', D) / 365) AS W_DAY,
    MONTH(D) = 11 OR (MONTH(D) = 12 AND DAY(D) <= 24) AS IS_XMAS
  FROM d),
sd AS (
  SELECT s.STORE_ID, dw.D, dw.IS_XMAS,
    ROUND(12 * CASE s.STORE_FORMAT WHEN 'SUPERSTORE' THEN 1.4 WHEN 'STANDARD' THEN 1.0 ELSE 0.7 END * dw.W_DAY
          * (0.85 + 0.3 * MOD(ABS(HASH(s.STORE_ID, dw.D, 'n')), 1000) / 1000)) AS N_ORDERS
  FROM WILDERNESS_HOL.RAW.DIM_STORE s CROSS JOIN dw)
SELECT sd.STORE_ID, sd.D AS ORDER_DATE, n.K,
  MOD(ABS(HASH(sd.STORE_ID, sd.D, n.K, 'size')), 4) + 1 AS ORDER_SIZE,
  sd.D NOT BETWEEN '2026-11-01' AND '2026-11-03'
    AND MOD(ABS(HASH(sd.STORE_ID, sd.D, n.K, 'tent')), 1000) < IFF(sd.IS_XMAS, 250, 100) AS IS_TENT,
  'N' AS SRC
FROM sd JOIN WILDERNESS_HOL.SETUP.GEN_NUM n ON n.K < sd.N_ORDERS;

-- -------------------------------------------------------------------------------------
-- 5. SIGNAL (demand in the wrong place): launch weekend 2026 tent orders are copied from 2025
-- -------------------------------------------------------------------------------------
-- Each store's tent orders on 1-3 Nov 2026 = its tent orders on 1-3 Nov 2025 x 1.6 in NSW
-- and QLD, x 1.1 everywhere else. Rounding is shared out inside each state, so each state's
-- growth is exact. Every tent order holds one tent, so orders = units.
INSERT INTO WILDERNESS_HOL.SETUP.GEN_ORDER_SRC
WITH t25 AS (
  SELECT o.STORE_ID, s.STATE, COUNT(*) AS T25
  FROM WILDERNESS_HOL.SETUP.GEN_ORDER_SRC o JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = o.STORE_ID
  WHERE o.IS_TENT AND o.ORDER_DATE BETWEEN '2025-11-01' AND '2025-11-03'
  GROUP BY 1, 2),
x AS (SELECT *, T25 * IFF(STATE IN ('NSW', 'QLD'), 1.6, 1.1) AS X FROM t25),
r AS (
  SELECT STORE_ID, FLOOR(X) AS FL,
         ROUND(SUM(X) OVER (PARTITION BY STATE)) - SUM(FLOOR(X)) OVER (PARTITION BY STATE) AS EXTRA,
         ROW_NUMBER() OVER (PARTITION BY STATE ORDER BY X - FLOOR(X) DESC, STORE_ID) AS RK
  FROM x),
t26 AS (SELECT STORE_ID, FL + IFF(RK <= EXTRA, 1, 0) AS T26 FROM r)
SELECT t.STORE_ID, DATEADD(day, MOD(n.K, 3), '2026-11-01'::DATE), n.K,
       MOD(ABS(HASH(t.STORE_ID, n.K, 'lsize')), 2) + 3, TRUE, 'L'
FROM t26 t JOIN WILDERNESS_HOL.SETUP.GEN_NUM n ON n.K < t.T26;

CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_ORDERS AS
SELECT ROW_NUMBER() OVER (ORDER BY ORDER_DATE, STORE_ID, SRC, K) AS ORDER_N,
       ORDER_DATE, STORE_ID, ORDER_SIZE, IS_TENT
FROM WILDERNESS_HOL.SETUP.GEN_ORDER_SRC;

-- -------------------------------------------------------------------------------------
-- 6. Sales lines
-- -------------------------------------------------------------------------------------
-- SIGNAL (basket): in a tent order line 1 is a tent; line 2 is sleeping gear 61% of the time,
-- line 3 cooking gear 34%, line 4 a light 28% (3-line orders put a light on line 3 when it
-- is not cooking gear). Other lines in a tent order are never tents or kit.
-- Products: the Summit Tent is 28% of tent lines and the Overland 3P 14%; the Trailhead mat is
-- 15% and the Coastline bag 12% of sleeping lines; everything else is spread evenly.
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_LINES AS
WITH l AS (
  SELECT o.ORDER_N, o.ORDER_DATE, o.STORE_ID, o.ORDER_SIZE, o.IS_TENT, n.K + 1 AS LINE_POS,
         MOD(ABS(HASH(o.ORDER_N, n.K, 'slot')), 1000000) / 1000000 AS U_SLOT,
         MOD(ABS(HASH(o.ORDER_N, n.K, 'slot2')), 1000000) / 1000000 AS U_SLOT2,
         MOD(ABS(HASH(o.ORDER_N, n.K, 'cat')), 1000000) / 1000000 AS U_CAT,
         MOD(ABS(HASH(o.ORDER_N, n.K, 'prod')), 1000000) / 1000000 AS U_PROD,
         MOD(ABS(HASH(o.ORDER_N, n.K, 'prod2')), 1000000) / 1000000 AS U_PROD2
  FROM WILDERNESS_HOL.SETUP.GEN_ORDERS o JOIN WILDERNESS_HOL.SETUP.GEN_NUM n ON n.K < o.ORDER_SIZE),
s AS (
  SELECT l.*,
    CASE
      WHEN IS_TENT AND LINE_POS = 1 THEN 'TENT'
      WHEN IS_TENT AND LINE_POS = 2 THEN IFF(U_SLOT < 0.61, 'SLEEP', 'FILLER')
      WHEN IS_TENT AND ORDER_SIZE = 4 AND LINE_POS = 3 THEN IFF(U_SLOT < 0.34, 'COOK', 'FILLER')
      WHEN IS_TENT AND ORDER_SIZE = 4 AND LINE_POS = 4 THEN IFF(U_SLOT < 0.28, 'LIGHT', 'FILLER')
      WHEN IS_TENT AND ORDER_SIZE = 3 AND LINE_POS = 3
        THEN IFF(U_SLOT < 0.34, 'COOK', IFF(U_SLOT2 < 0.4242, 'LIGHT', 'FILLER'))
      ELSE 'GENERAL' END AS SLOT
  FROM l),
-- Category ranges for GENERAL (any non-tent line) and FILLER (non-tent, non-kit) lines.
cr AS (
  SELECT 'GENERAL' AS KIND, CAT_ORD, SUM(W_GENERAL) OVER (ORDER BY CAT_ORD) - W_GENERAL AS LO,
         SUM(W_GENERAL) OVER (ORDER BY CAT_ORD) AS HI, SUM(W_GENERAL) OVER () AS TOT
  FROM WILDERNESS_HOL.SETUP.GEN_CATEGORY WHERE W_GENERAL > 0
  UNION ALL
  SELECT 'FILLER', CAT_ORD, SUM(W_FILLER) OVER (ORDER BY CAT_ORD) - W_FILLER,
         SUM(W_FILLER) OVER (ORDER BY CAT_ORD), SUM(W_FILLER) OVER ()
  FROM WILDERNESS_HOL.SETUP.GEN_CATEGORY WHERE W_FILLER > 0),
c AS (
  SELECT s.*,
    CASE SLOT WHEN 'TENT' THEN 1 WHEN 'SLEEP' THEN 2 WHEN 'COOK' THEN 3 WHEN 'LIGHT' THEN 4 ELSE cr.CAT_ORD END AS CAT_ORD
  FROM s LEFT JOIN cr
    ON cr.KIND = s.SLOT AND s.U_CAT * cr.TOT >= cr.LO AND s.U_CAT * cr.TOT < cr.HI),
p AS (
  SELECT c.*,
    CASE
      WHEN c.CAT_ORD = 1 AND U_PROD < 0.28 THEN 2
      WHEN c.CAT_ORD = 1 AND U_PROD < 0.42 THEN 3
      WHEN c.CAT_ORD = 2 AND U_PROD < 0.15 THEN 1
      WHEN c.CAT_ORD = 2 AND U_PROD < 0.27 THEN 110
      ELSE 1 + FLOOR(U_PROD2 * g.N) END AS IDX
  FROM c JOIN WILDERNESS_HOL.SETUP.GEN_CATEGORY g ON g.CAT_ORD = c.CAT_ORD)
SELECT ROW_NUMBER() OVER (ORDER BY p.ORDER_N, p.LINE_POS) AS LINE_N,
       p.ORDER_N, p.ORDER_DATE, p.STORE_ID, p.CAT_ORD, gp.PRODUCT_ID,
       IFF(MOD(ABS(HASH(p.ORDER_N, 'mem')), 100) < 70,
           'M' || LPAD(1 + MOD(ABS(HASH(p.ORDER_N, 'mid')), 180000), 6, '0'), NULL) AS MEMBER_ID
FROM p JOIN WILDERNESS_HOL.SETUP.GEN_PRODUCT gp ON gp.CAT_ORD = p.CAT_ORD AND gp.IDX = p.IDX;

CREATE OR REPLACE TABLE WILDERNESS_HOL.RAW.FCT_SALES_LINE AS
WITH x AS (
  SELECT g.*, p.UNIT_COST, p.RRP,
    IFF(g.CAT_ORD IN (3, 4, 8),
        CASE WHEN MOD(ABS(HASH(g.LINE_N, 'qty')), 100) < 85 THEN 1
             WHEN MOD(ABS(HASH(g.LINE_N, 'qty')), 100) < 97 THEN 2 ELSE 3 END, 1) AS QUANTITY,
    CASE
      WHEN p.IN_CHRISTMAS_CATALOGUE AND ((MONTH(g.ORDER_DATE) = 12 AND DAY(g.ORDER_DATE) >= 26)
                                         OR (MONTH(g.ORDER_DATE) = 1 AND DAY(g.ORDER_DATE) = 1)) THEN 0.30
      WHEN MOD(ABS(HASH(g.LINE_N, 'promo')), 100) < 8 THEN 0.10
      WHEN MOD(ABS(HASH(g.LINE_N, 'promo')), 100) < 15 THEN 0.20
      ELSE 0 END AS DISC_PCT,
    MOD(ABS(HASH(g.LINE_N, 'batch')), 100) AS H_BATCH
  FROM WILDERNESS_HOL.SETUP.GEN_LINES g JOIN WILDERNESS_HOL.SETUP.GEN_PRODUCT p ON p.PRODUCT_ID = g.PRODUCT_ID)
SELECT
  'L' || LPAD(LINE_N, 7, '0') AS SALE_LINE_ID,
  'O' || LPAD(ORDER_N, 7, '0') AS ORDER_ID,
  ORDER_DATE, STORE_ID, PRODUCT_ID, MEMBER_ID, QUANTITY,
  RRP AS UNIT_PRICE,
  ROUND(QUANTITY * RRP * DISC_PCT, 2)::NUMBER(12,2) AS DISCOUNT_AMOUNT,
  (QUANTITY * RRP - ROUND(QUANTITY * RRP * DISC_PCT, 2))::NUMBER(12,2) AS NET_SALES_AMOUNT,
  (QUANTITY * UNIT_COST)::NUMBER(12,2) AS COST_AMOUNT,
  -- SIGNAL (faulty batch): Summit Tents sold from 1 Jul 2026 are 70% batch B26-07, 30% B26-02.
  CASE
    WHEN CAT_ORD <> 1 THEN NULL
    WHEN PRODUCT_ID = 'SKU-TNT-0102' AND ORDER_DATE >= '2026-07-01' THEN IFF(H_BATCH < 70, 'B26-07', 'B26-02')
    WHEN PRODUCT_ID = 'SKU-TNT-0102' AND ORDER_DATE >= '2026-02-01' THEN 'B26-02'
    ELSE 'B' || RIGHT(YEAR(ORDER_DATE)::VARCHAR, 2) || IFF(MONTH(ORDER_DATE) <= 6, '-03', '-09') END AS BATCH_CODE
FROM x
ORDER BY SALE_LINE_ID;

-- -------------------------------------------------------------------------------------
-- 7. Returns: each one points at a real sale line
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE TABLE WILDERNESS_HOL.RAW.FCT_RETURN AS
WITH s AS (
  SELECT f.SALE_LINE_ID, f.ORDER_DATE, f.STORE_ID, f.PRODUCT_ID, f.QUANTITY, f.NET_SALES_AMOUNT, f.BATCH_CODE,
         p.SUBCATEGORY,
         MOD(ABS(HASH(f.SALE_LINE_ID, 'ret')), 1000000) / 1000000 AS U_R,
         MOD(ABS(HASH(f.SALE_LINE_ID, 'lag')), 1000000) / 1000000 AS U_L,
         MOD(ABS(HASH(f.SALE_LINE_ID, 'why')), 1000000) / 1000000 AS U_W
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = f.PRODUCT_ID),
r AS (
  SELECT s.*,
    -- SIGNAL (faulty batch): Summit Tent B26-07 is returned ~4x as often as B26-02, and sooner.
    CASE WHEN PRODUCT_ID = 'SKU-TNT-0102' AND BATCH_CODE = 'B26-07' THEN 0.19
         WHEN PRODUCT_ID = 'SKU-TNT-0102' THEN 0.04
         WHEN SUBCATEGORY IN ('Hiking Boots','Sandals') THEN 0.11
         ELSE 0.048 END AS P_RET,
    DATEADD(day, CASE
      WHEN PRODUCT_ID = 'SKU-TNT-0102' AND BATCH_CODE = 'B26-07' AND ORDER_DATE >= '2026-10-20'
        THEN 1 + FLOOR(U_L * DATEDIFF(day, ORDER_DATE, '2026-11-03'))
      WHEN PRODUCT_ID = 'SKU-TNT-0102' AND BATCH_CODE = 'B26-07' THEN 1 + FLOOR(U_L * 14)
      ELSE 1 + FLOOR(U_L * 30) END, ORDER_DATE) AS RETURN_DATE
  FROM s)
SELECT
  'R' || LPAD(ROW_NUMBER() OVER (ORDER BY SALE_LINE_ID), 7, '0') AS RETURN_ID,
  SALE_LINE_ID, RETURN_DATE, STORE_ID, PRODUCT_ID,
  QUANTITY AS RETURN_QUANTITY, NET_SALES_AMOUNT AS REFUND_AMOUNT,
  CASE
    WHEN PRODUCT_ID = 'SKU-TNT-0102' AND BATCH_CODE = 'B26-07'
      THEN CASE WHEN U_W < 0.82 THEN 'FAULTY' WHEN U_W < 0.92 THEN 'CHANGE_OF_MIND' ELSE 'OTHER' END
    WHEN PRODUCT_ID = 'SKU-TNT-0102'
      THEN CASE WHEN U_W < 0.35 THEN 'FAULTY' WHEN U_W < 0.80 THEN 'CHANGE_OF_MIND' ELSE 'OTHER' END
    WHEN SUBCATEGORY IN ('Hiking Boots','Sandals')
      THEN CASE WHEN U_W < 0.82 THEN 'WRONG_SIZE' WHEN U_W < 0.92 THEN 'CHANGE_OF_MIND' ELSE 'FAULTY' END
    ELSE CASE WHEN U_W < 0.25 THEN 'FAULTY' WHEN U_W < 0.75 THEN 'CHANGE_OF_MIND' ELSE 'OTHER' END
  END AS RETURN_REASON_CODE,
  BATCH_CODE
FROM r
WHERE U_R < P_RET AND RETURN_DATE <= '2026-11-03'
ORDER BY RETURN_ID;

-- -------------------------------------------------------------------------------------
-- 8. Stock at 3 Nov 2026: 72 stores x 1,200 products, plus a second Summit Tent batch row
-- -------------------------------------------------------------------------------------
-- SIGNAL (40% more tents, everywhere): each store holds 1.4x the tents it sold from 4 Nov to
-- 24 Dec 2025, shared across its tents in proportion to last year's sales (rounding shared out
-- inside the store). Everything else: 1.2x last year's units for the same weeks.
-- Nothing is on order.
CREATE OR REPLACE TABLE WILDERNESS_HOL.RAW.FCT_INVENTORY AS
WITH ly AS (
  SELECT STORE_ID, PRODUCT_ID,
         SUM(IFF(ORDER_DATE >= '2025-11-04', QUANTITY, 0)) AS LY_REST,
         SUM(QUANTITY) AS LY_XMAS
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE
  WHERE ORDER_DATE BETWEEN '2025-11-01' AND '2025-12-24'
  GROUP BY 1, 2),
g AS (
  SELECT s.STORE_ID, p.PRODUCT_ID, p.CATEGORY = 'Tents & Shelters' AS IS_TENT,
         COALESCE(ly.LY_REST, 0) AS LY_REST, COALESCE(ly.LY_XMAS, 0) AS LY_XMAS
  FROM WILDERNESS_HOL.RAW.DIM_STORE s
  CROSS JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p
  LEFT JOIN ly ON ly.STORE_ID = s.STORE_ID AND ly.PRODUCT_ID = p.PRODUCT_ID),
t AS (
  SELECT g.*, IFF(IS_TENT, 1.4, 1.2) * LY_REST AS X,
         ROUND(SUM(IFF(IS_TENT, 1.4 * LY_REST, 0)) OVER (PARTITION BY STORE_ID))
           - SUM(IFF(IS_TENT, FLOOR(1.4 * LY_REST), 0)) OVER (PARTITION BY STORE_ID) AS EXTRA,
         ROW_NUMBER() OVER (PARTITION BY STORE_ID, IS_TENT
                            ORDER BY 1.4 * LY_REST - FLOOR(1.4 * LY_REST) DESC, PRODUCT_ID) AS RK
  FROM g),
s AS (
  SELECT STORE_ID, PRODUCT_ID, ROUND(LY_XMAS / (54 / 7), 2) AS AVG_WEEKLY,
         IFF(IS_TENT, FLOOR(X) + IFF(RK <= EXTRA, 1, 0), ROUND(X)) AS STOCK
  FROM t),
rows_ AS (
  -- Everything except the Summit Tent: one row, latest tent batch code on tents.
  SELECT s.STORE_ID, s.PRODUCT_ID, IFF(p.CATEGORY = 'Tents & Shelters', 'B26-09', NULL) AS BATCH_CODE,
         s.STOCK AS ON_HAND, s.AVG_WEEKLY
  FROM s JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = s.PRODUCT_ID
  WHERE s.PRODUCT_ID <> 'SKU-TNT-0102'
  UNION ALL
  -- SIGNAL (send it back): 40% of every store's Summit Tents are the faulty batch B26-07.
  -- B26-07 did not exist last Christmas, so its row carries no LY rate.
  SELECT STORE_ID, PRODUCT_ID, 'B26-07', ROUND(0.40 * STOCK), 0
  FROM s WHERE PRODUCT_ID = 'SKU-TNT-0102'
  UNION ALL
  SELECT STORE_ID, PRODUCT_ID, 'B26-02', STOCK - ROUND(0.40 * STOCK), AVG_WEEKLY
  FROM s WHERE PRODUCT_ID = 'SKU-TNT-0102')
SELECT '2026-11-03'::DATE AS SNAPSHOT_DATE, STORE_ID, PRODUCT_ID, BATCH_CODE,
       ON_HAND::NUMBER(10,0) AS ON_HAND_UNITS, 0::NUMBER(10,0) AS ON_ORDER_UNITS,
       AVG_WEEKLY::NUMBER(10,2) AS AVG_WEEKLY_UNITS_LY_XMAS,
       ROUND(ON_HAND / NULLIF(AVG_WEEKLY, 0), 1)::NUMBER(10,1) AS WEEKS_OF_COVER
FROM rows_
ORDER BY STORE_ID, PRODUCT_ID, BATCH_CODE;

-- -------------------------------------------------------------------------------------
-- 9. Clean up helpers and log
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_CATEGORY;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_PRODUCT;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_NUM;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_ORDER_SRC;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_ORDERS;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_LINES;

CALL WILDERNESS_HOL.SETUP.LOG_STEP('STRUCTURED_DATA', 'OK',
  (SELECT COUNT(*) FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE));
