-- =====================================================================================
-- 12_generate_structured.sql  ·  Wilderness Outfitters workshop
-- Stores, products, members, sales lines, returns and the 3 Nov 2026 stock snapshot.
--
-- Every value is derived from HASH(<row id>, '<salt>'), so every account gets exactly
-- the same rows. The window is 1 Jul 2024 to 3 Nov 2026; nothing reads today's date.
-- Background data is plain. Each story signal is set by its own labelled block.
-- Helper tables live in GIT as GEN_* and are dropped at the end.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WILDERNESS_WH;

-- -------------------------------------------------------------------------------------
-- 1. Stores: 72 stores and ONLINE
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
  ('S072','Wilderness Tuggeranong','ACT','METRO','STANDARD',-35.4190,149.0880),
  ('ONLINE','Wilderness Online',NULL,NULL,'ONLINE',NULL,NULL);

-- -------------------------------------------------------------------------------------
-- 2. Products: 1,200 across 10 categories
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_CATEGORY AS
SELECT $1 AS CAT_ORD, $2 AS CATEGORY, $3 AS CODE, $4 AS N, $5 AS KIT_GROUP, $6 AS COST_LO, $7 AS COST_HI,
       $8 AS SUPPLIER_ID, $9 AS SUPPLIER_NAME, $10 AS W_GENERAL, $11 AS W_FILLER,
       SPLIT($12, '|') AS SUBS, SPLIT($13, '|') AS NOUNS
FROM VALUES
  (1,'Tents & Shelters','TNT',90,'SHELTER',90,600,'SUP-01','Kestrel Shelters',0,0,
     'Hiking Tents|Family Tents|Swags|Gazebos','Hiking Tent|Family Tent|Swag|Gazebo'),
  (2,'Sleeping','SLP',110,'SLEEP',18,80,'SUP-02','Dreamtrail Sleep Co',10,0,
     'Sleeping Bags|Sleeping Mats|Air Beds|Camp Pillows','Sleeping Bag|Sleeping Mat|Air Bed|Camp Pillow'),
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
  ('SKU-TNT-0102','Summit 2P Tent','Hiking Tents','SUP-01','Kestrel Shelters',290.00,649.00),
  ('SKU-TNT-0103','Summit 3P Tent','Hiking Tents','SUP-01','Kestrel Shelters',380.00,849.00),
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
CREATE OR REPLACE TABLE WILDERNESS_HOL.RAW.DIM_MEMBER AS
WITH n AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS MN FROM TABLE(GENERATOR(ROWCOUNT => 180000))),
s AS (SELECT STORE_ID, STATE, ROW_NUMBER() OVER (ORDER BY STORE_ID) AS SN
      FROM WILDERNESS_HOL.RAW.DIM_STORE WHERE STORE_ID <> 'ONLINE'),
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
-- 4. Pick tables: days, stores, categories, products (hashed bucket -> value)
-- -------------------------------------------------------------------------------------
-- Day weights: Christmas period 1 Nov - 24 Dec x2.2, launch weekend 1-3 Nov 2026 x2.6,
-- Boxing Day week x1.8, Easter week x1.4, Christmas Day x0.3, and 15% a year growth.
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_DAY_PICK AS
WITH d AS (SELECT DATEADD(day, ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, '2024-07-01'::DATE) AS D
           FROM TABLE(GENERATOR(ROWCOUNT => 856))),
w AS (
  SELECT D,
    (CASE
       WHEN D BETWEEN '2026-11-01' AND '2026-11-03' THEN 2.6
       WHEN MONTH(D) = 12 AND DAY(D) = 25 THEN 0.3
       WHEN MONTH(D) = 11 OR (MONTH(D) = 12 AND DAY(D) <= 24) THEN 2.2
       WHEN (MONTH(D) = 12 AND DAY(D) >= 26) OR (MONTH(D) = 1 AND DAY(D) = 1) THEN 1.8
       WHEN D BETWEEN '2025-04-14' AND '2025-04-21' OR D BETWEEN '2026-03-30' AND '2026-04-06' THEN 1.4
       ELSE 1.0 END) * (1 + 0.15 * DATEDIFF(day, '2024-07-01', D) / 365) AS W
  FROM d),
c AS (SELECT D, W, SUM(W) OVER (ORDER BY D) AS CUM, SUM(W) OVER () AS TOT FROM w),
b AS (SELECT D, FLOOR((CUM - W) / TOT * 100000) AS LO, FLOOR(CUM / TOT * 100000) AS HI FROM c),
n AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS BUCKET FROM TABLE(GENERATOR(ROWCOUNT => 100000)))
SELECT n.BUCKET, b.D FROM n JOIN b ON n.BUCKET >= b.LO AND n.BUCKET < b.HI;

-- Store weights: superstore 1.4, standard 1.0, compact 0.7; online takes 6.4% of orders.
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_STORE_PICK AS
WITH w AS (
  SELECT STORE_ID,
    CASE STORE_FORMAT WHEN 'SUPERSTORE' THEN 1.4 WHEN 'STANDARD' THEN 1.0 WHEN 'COMPACT' THEN 0.7 ELSE 0 END AS W0
  FROM WILDERNESS_HOL.RAW.DIM_STORE),
w2 AS (SELECT STORE_ID, IFF(STORE_ID = 'ONLINE', SUM(W0) OVER () * 0.064 / 0.936, W0) AS W FROM w),
c AS (SELECT STORE_ID, W, SUM(W) OVER (ORDER BY STORE_ID) AS CUM, SUM(W) OVER () AS TOT FROM w2),
b AS (SELECT STORE_ID, FLOOR((CUM - W) / TOT * 10000) AS LO, FLOOR(CUM / TOT * 10000) AS HI FROM c),
n AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS BUCKET FROM TABLE(GENERATOR(ROWCOUNT => 10000)))
SELECT n.BUCKET, b.STORE_ID FROM n JOIN b ON n.BUCKET >= b.LO AND n.BUCKET < b.HI;

-- Category picks: GENERAL (any non-tent line) and FILLER (non-tent, non-kit).
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_CAT_PICK AS
WITH k AS (SELECT 'GENERAL' AS KIND, CAT_ORD, W_GENERAL AS W FROM WILDERNESS_HOL.SETUP.GEN_CATEGORY WHERE W_GENERAL > 0
           UNION ALL
           SELECT 'FILLER', CAT_ORD, W_FILLER FROM WILDERNESS_HOL.SETUP.GEN_CATEGORY WHERE W_FILLER > 0),
c AS (SELECT KIND, CAT_ORD, W, SUM(W) OVER (PARTITION BY KIND ORDER BY CAT_ORD) AS CUM,
             SUM(W) OVER (PARTITION BY KIND) AS TOT FROM k),
b AS (SELECT KIND, CAT_ORD, FLOOR((CUM - W) / TOT * 1000) AS LO, FLOOR(CUM / TOT * 1000) AS HI FROM c),
n AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS BUCKET FROM TABLE(GENERATOR(ROWCOUNT => 1000)))
SELECT b.KIND, n.BUCKET, b.CAT_ORD FROM n JOIN b ON n.BUCKET >= b.LO AND n.BUCKET < b.HI;

-- Product picks within a category. SIGNAL: hero products take fixed shares
-- (Summit 2P 28% and Summit 3P 14% of tent lines; Trailhead mat 15% and Coastline bag 12% of sleeping lines).
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_PROD_PICK AS
WITH n AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS BUCKET FROM TABLE(GENERATOR(ROWCOUNT => 1000))),
hero AS (SELECT * FROM VALUES
  (1,'SKU-TNT-0102',0,280),(1,'SKU-TNT-0103',280,420),
  (2,'SKU-SLP-0201',0,150),(2,'SKU-SLP-0310',150,270) AS v(CAT_ORD, PRODUCT_ID, LO, HI)),
hs AS (SELECT c.CAT_ORD, COALESCE(MAX(h.HI), 0) AS FIRST_BUCKET
          FROM WILDERNESS_HOL.SETUP.GEN_CATEGORY c LEFT JOIN hero h ON h.CAT_ORD = c.CAT_ORD GROUP BY c.CAT_ORD),
rest AS (SELECT p.CAT_ORD, p.PRODUCT_ID,
                ROW_NUMBER() OVER (PARTITION BY p.CAT_ORD ORDER BY p.PRODUCT_ID) - 1 AS K,
                COUNT(*) OVER (PARTITION BY p.CAT_ORD) AS NP
         FROM WILDERNESS_HOL.SETUP.GEN_PRODUCT p
         WHERE p.PRODUCT_ID NOT IN (SELECT PRODUCT_ID FROM hero))
SELECT h.CAT_ORD, n.BUCKET, h.PRODUCT_ID FROM n JOIN hero h ON n.BUCKET >= h.LO AND n.BUCKET < h.HI
UNION ALL
SELECT s.CAT_ORD, n.BUCKET, r.PRODUCT_ID
FROM n JOIN hs s ON n.BUCKET >= s.FIRST_BUCKET
JOIN rest r ON r.CAT_ORD = s.CAT_ORD AND r.K = FLOOR((n.BUCKET - s.FIRST_BUCKET) * r.NP / (1000 - s.FIRST_BUCKET));

-- -------------------------------------------------------------------------------------
-- 5. Orders: 1,200,000, sizes 1/2/3/4 in turn = exactly 3,000,000 lines
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_ORDERS AS
WITH o AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS ORDER_N FROM TABLE(GENERATOR(ROWCOUNT => 1200000))),
a AS (
  SELECT o.ORDER_N, MOD(o.ORDER_N - 1, 4) + 1 AS ORDER_SIZE, dp.D AS ORDER_DATE,
         st.STORE_ID, st.STATE, st.REGION_TYPE,
         IFF(MOD(ABS(HASH(o.ORDER_N, 'mem')), 100) < 70,
             'M' || LPAD(1 + MOD(ABS(HASH(o.ORDER_N, 'mid')), 180000), 6, '0'), NULL) AS MEMBER_ID,
         MOD(ABS(HASH(o.ORDER_N, 'tent')), 1000000) / 1000000 AS U_TENT
  FROM o
  JOIN WILDERNESS_HOL.SETUP.GEN_DAY_PICK dp ON dp.BUCKET = MOD(ABS(HASH(o.ORDER_N, 'day')), 100000)
  JOIN WILDERNESS_HOL.SETUP.GEN_STORE_PICK sp ON sp.BUCKET = MOD(ABS(HASH(o.ORDER_N, 'store')), 10000)
  JOIN WILDERNESS_HOL.RAW.DIM_STORE st ON st.STORE_ID = sp.STORE_ID)
SELECT a.*,
  -- Tent orders are 3- or 4-line baskets. Christmas period 55% of those, otherwise 22%.
  -- SIGNAL (demand in the wrong place): on 1-3 Nov 2026 the tent share is x1.091 in NSW/QLD and
  -- x0.790 in VIC/TAS/SA, which with the x2.6 launch weekend and growth gives +45% / +5% tent units YoY.
  ORDER_SIZE >= 3 AND U_TENT <
    (IFF(MONTH(ORDER_DATE) = 11 OR (MONTH(ORDER_DATE) = 12 AND DAY(ORDER_DATE) <= 24), 0.55, 0.22)
     * IFF(ORDER_DATE BETWEEN '2026-11-01' AND '2026-11-03',
           CASE WHEN STATE IN ('NSW','QLD') THEN 1.091 WHEN STATE IN ('VIC','TAS','SA') THEN 0.790 ELSE 1 END, 1))
    AS IS_TENT_ORDER
FROM a;

-- -------------------------------------------------------------------------------------
-- 6. Sales lines
-- -------------------------------------------------------------------------------------
-- SIGNAL (kit attach): in a tent order, line 2 is sleeping gear 61% of the time, line 3 cook 34%,
-- line 4 lighting 28% (3-line orders put lighting on line 3 when it is not cook). The other lines
-- in a tent order are never tents or kit, so attach rates are exact by construction.
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_LINES AS
WITH l AS (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS LINE_N FROM TABLE(GENERATOR(ROWCOUNT => 3000000))),
lo AS (
  SELECT LINE_N,
    FLOOR((LINE_N - 1) / 10) * 4 + CASE WHEN MOD(LINE_N - 1, 10) = 0 THEN 1 WHEN MOD(LINE_N - 1, 10) <= 2 THEN 2
                                        WHEN MOD(LINE_N - 1, 10) <= 5 THEN 3 ELSE 4 END AS ORDER_N,
    CASE WHEN MOD(LINE_N - 1, 10) = 0 THEN 1 WHEN MOD(LINE_N - 1, 10) <= 2 THEN MOD(LINE_N - 1, 10)
         WHEN MOD(LINE_N - 1, 10) <= 5 THEN MOD(LINE_N - 1, 10) - 2 ELSE MOD(LINE_N - 1, 10) - 5 END AS LINE_POS,
    MOD(ABS(HASH(LINE_N, 'slot')), 1000000) / 1000000 AS U_SLOT,
    MOD(ABS(HASH(LINE_N, 'slot2')), 1000000) / 1000000 AS U_SLOT2,
    MOD(ABS(HASH(LINE_N, 'snow')), 1000000) / 1000000 AS U_SNOW
  FROM l),
s AS (
  SELECT lo.*, o.ORDER_SIZE, o.ORDER_DATE, o.STORE_ID, o.REGION_TYPE, o.MEMBER_ID,
    CASE
      WHEN o.IS_TENT_ORDER AND LINE_POS = 1 THEN 'TENT'
      WHEN o.IS_TENT_ORDER AND LINE_POS = 2 THEN IFF(U_SLOT < 0.61, 'SLEEP', 'FILLER')
      WHEN o.IS_TENT_ORDER AND ORDER_SIZE = 4 AND LINE_POS = 3 THEN IFF(U_SLOT < 0.34, 'COOK', 'FILLER')
      WHEN o.IS_TENT_ORDER AND ORDER_SIZE = 4 AND LINE_POS = 4 THEN IFF(U_SLOT < 0.28, 'LIGHT', 'FILLER')
      WHEN o.IS_TENT_ORDER AND ORDER_SIZE = 3 AND LINE_POS = 3
        THEN IFF(U_SLOT < 0.34, 'COOK', IFF(U_SLOT2 < 0.4242, 'LIGHT', 'FILLER'))
      ELSE 'GENERAL' END AS SLOT
  FROM lo JOIN WILDERNESS_HOL.SETUP.GEN_ORDERS o ON o.ORDER_N = lo.ORDER_N),
c AS (
  SELECT s.*,
    CASE SLOT WHEN 'TENT' THEN 1 WHEN 'SLEEP' THEN 2 WHEN 'COOK' THEN 3 WHEN 'LIGHT' THEN 4
      WHEN 'FILLER' THEN cf.CAT_ORD
      ELSE IFF(REGION_TYPE = 'ALPINE' AND MONTH(ORDER_DATE) BETWEEN 6 AND 8 AND U_SNOW < 0.2, 10, cg.CAT_ORD)
    END AS CAT_ORD
  FROM s
  LEFT JOIN WILDERNESS_HOL.SETUP.GEN_CAT_PICK cf
    ON cf.KIND = 'FILLER' AND cf.BUCKET = MOD(ABS(HASH(s.LINE_N, 'filler')), 1000)
  LEFT JOIN WILDERNESS_HOL.SETUP.GEN_CAT_PICK cg
    ON cg.KIND = 'GENERAL' AND cg.BUCKET = MOD(ABS(HASH(s.LINE_N, 'general')), 1000))
SELECT c.LINE_N, c.ORDER_N, c.ORDER_DATE, c.STORE_ID, c.MEMBER_ID, c.CAT_ORD, pp.PRODUCT_ID
FROM c JOIN WILDERNESS_HOL.SETUP.GEN_PROD_PICK pp
  ON pp.CAT_ORD = c.CAT_ORD AND pp.BUCKET = MOD(ABS(HASH(c.LINE_N, 'product')), 1000);

CREATE OR REPLACE TABLE WILDERNESS_HOL.RAW.FCT_SALES_LINE AS
WITH x AS (
  SELECT g.*, p.UNIT_COST, p.RRP, p.IN_CHRISTMAS_CATALOGUE,
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
  -- SIGNAL (faulty batch): Summit 2P sold from 1 Jul 2026 is 70% batch B26-07, 30% B26-02.
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
    -- SIGNAL (faulty batch): Summit 2P B26-07 is returned ~4x as often as B26-02, and sooner.
    CASE WHEN PRODUCT_ID = 'SKU-TNT-0102' AND BATCH_CODE = 'B26-07' THEN 0.19
         WHEN PRODUCT_ID = 'SKU-TNT-0102' THEN 0.04
         WHEN SUBCATEGORY IN ('Hiking Boots','Sandals') THEN 0.11
         ELSE 0.048 END AS P_RET,
    -- SIGNAL (peak week to 3 Nov): B26-07 tents sold from 20 Oct come back before 3 Nov.
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
-- 8. Stock snapshot at 3 Nov 2026: 72 stores x 1,200 products, plus a second Summit 2P batch row
-- -------------------------------------------------------------------------------------
-- Forecast terms used below are the ones V_KIT_COVER and V_CHRISTMAS_STOCK_RISK use (spec S5-S7):
--   index         = units 1-3 Nov 2026 / units 1-3 Nov 2025, by state and category
--   weekly        = AVG_WEEKLY_UNITS_LY_XMAS x index;  forecast to 24 Dec = weekly x 51/7
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_INV_BASE AS
WITH ly AS (
  SELECT STORE_ID, PRODUCT_ID, SUM(QUANTITY) AS LY_UNITS
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE
  WHERE ORDER_DATE BETWEEN '2025-11-01' AND '2025-12-24' AND STORE_ID <> 'ONLINE'
  GROUP BY 1, 2),
idx AS (
  SELECT s.STATE, p.CATEGORY,
         SUM(IFF(f.ORDER_DATE BETWEEN '2026-11-01' AND '2026-11-03', f.QUANTITY, 0))
         / NULLIF(SUM(IFF(f.ORDER_DATE BETWEEN '2025-11-01' AND '2025-11-03', f.QUANTITY, 0)), 0) AS IDX
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f
  JOIN WILDERNESS_HOL.RAW.DIM_STORE s ON s.STORE_ID = f.STORE_ID
  JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = f.PRODUCT_ID
  WHERE f.ORDER_DATE BETWEEN '2025-11-01' AND '2025-11-03' OR f.ORDER_DATE BETWEEN '2026-11-01' AND '2026-11-03'
  GROUP BY 1, 2),
g AS (
  SELECT s.STORE_ID, s.STATE, p.PRODUCT_ID, p.CATEGORY, p.KIT_GROUP, p.IN_CHRISTMAS_CATALOGUE,
         COALESCE(ly.LY_UNITS, 0) AS LY_UNITS,
         ROUND(COALESCE(ly.LY_UNITS, 0) / (54 / 7), 2) AS AVG_WEEKLY,
         COALESCE(i.IDX, 1) AS IDX
  FROM WILDERNESS_HOL.RAW.DIM_STORE s
  CROSS JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p
  LEFT JOIN ly ON ly.STORE_ID = s.STORE_ID AND ly.PRODUCT_ID = p.PRODUCT_ID
  LEFT JOIN idx i ON i.STATE = s.STATE AND i.CATEGORY = p.CATEGORY
  WHERE s.STORE_ID <> 'ONLINE')
SELECT g.*, AVG_WEEKLY * IDX AS WEEKLY_FC, AVG_WEEKLY * IDX * 51 / 7 AS FC,
       MOD(ABS(HASH(STORE_ID, PRODUCT_ID, 'stock')), 1000000) / 1000000 AS U_STOCK
FROM g;

-- Kit need per store, as V_KIT_COVER computes it: tent forecast x last Christmas attach rate.
CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_KIT_NEED AS
WITH o AS (
  SELECT f.STORE_ID, f.ORDER_ID,
         MAX(IFF(p.CATEGORY = 'Tents & Shelters', 1, 0)) AS HAS_TENT,
         MAX(IFF(p.KIT_GROUP = 'SLEEP', 1, 0)) AS HAS_SLEEP,
         MAX(IFF(p.KIT_GROUP = 'COOK', 1, 0)) AS HAS_COOK,
         MAX(IFF(p.KIT_GROUP = 'LIGHT', 1, 0)) AS HAS_LIGHT
  FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE f JOIN WILDERNESS_HOL.RAW.DIM_PRODUCT p ON p.PRODUCT_ID = f.PRODUCT_ID
  WHERE f.ORDER_DATE BETWEEN '2025-11-01' AND '2025-12-24' AND f.STORE_ID <> 'ONLINE'
  GROUP BY 1, 2),
a AS (
  SELECT STORE_ID, AVG(HAS_SLEEP) AS A_SLEEP, AVG(HAS_COOK) AS A_COOK, AVG(HAS_LIGHT) AS A_LIGHT
  FROM o WHERE HAS_TENT = 1 GROUP BY 1),
t AS (SELECT STORE_ID, SUM(FC) AS TENT_FC FROM WILDERNESS_HOL.SETUP.GEN_INV_BASE
      WHERE CATEGORY = 'Tents & Shelters' GROUP BY 1)
SELECT t.STORE_ID, k.KIT_GROUP,
       t.TENT_FC * CASE k.KIT_GROUP WHEN 'SLEEP' THEN a.A_SLEEP WHEN 'COOK' THEN a.A_COOK ELSE a.A_LIGHT END AS NEEDED
FROM t JOIN a ON a.STORE_ID = t.STORE_ID
CROSS JOIN (SELECT * FROM VALUES ('SLEEP'),('COOK'),('LIGHT') AS v(KIT_GROUP)) k;

CREATE OR REPLACE TRANSIENT TABLE WILDERNESS_HOL.SETUP.GEN_INV_STOCK AS
WITH lists AS (SELECT * FROM VALUES
  -- SIGNAL (overstock): 14 stores, 11 VIC + 3 TAS, hold far more Summit 2P than they will sell.
  ('OVER_2P','S021'),('OVER_2P','S022'),('OVER_2P','S023'),('OVER_2P','S024'),('OVER_2P','S026'),
  ('OVER_2P','S027'),('OVER_2P','S029'),('OVER_2P','S031'),('OVER_2P','S033'),('OVER_2P','S035'),
  ('OVER_2P','S038'),('OVER_2P','S066'),('OVER_2P','S067'),('OVER_2P','S068'),
  -- SIGNAL (stockout next door): 11 NSW/QLD stores run out of Summit 3P before 20 Dec.
  ('SHORT_3P','S001'),('SHORT_3P','S002'),('SHORT_3P','S004'),('SHORT_3P','S008'),('SHORT_3P','S011'),
  ('SHORT_3P','S013'),('SHORT_3P','S015'),('SHORT_3P','S039'),('SHORT_3P','S040'),('SHORT_3P','S044'),
  ('SHORT_3P','S046'),
  -- SIGNAL (kit gap): 31 stores run out of sleeping gear in the week of 7 Dec.
  ('SHORT_SLEEP','S001'),('SHORT_SLEEP','S002'),('SHORT_SLEEP','S003'),('SHORT_SLEEP','S005'),
  ('SHORT_SLEEP','S006'),('SHORT_SLEEP','S007'),('SHORT_SLEEP','S009'),('SHORT_SLEEP','S010'),
  ('SHORT_SLEEP','S012'),('SHORT_SLEEP','S014'),('SHORT_SLEEP','S016'),('SHORT_SLEEP','S017'),
  ('SHORT_SLEEP','S019'),('SHORT_SLEEP','S039'),('SHORT_SLEEP','S041'),('SHORT_SLEEP','S042'),
  ('SHORT_SLEEP','S043'),('SHORT_SLEEP','S045'),('SHORT_SLEEP','S047'),('SHORT_SLEEP','S048'),
  ('SHORT_SLEEP','S049'),('SHORT_SLEEP','S050'),('SHORT_SLEEP','S051'),('SHORT_SLEEP','S025'),
  ('SHORT_SLEEP','S028'),('SHORT_SLEEP','S030'),('SHORT_SLEEP','S032'),('SHORT_SLEEP','S052'),
  ('SHORT_SLEEP','S054'),('SHORT_SLEEP','S061'),('SHORT_SLEEP','S070')
  AS v(LIST, STORE_ID)),
over_w AS (
  SELECT SUM(b.WEEKLY_FC) AS W_OVER FROM WILDERNESS_HOL.SETUP.GEN_INV_BASE b
  JOIN lists l ON l.LIST = 'OVER_2P' AND l.STORE_ID = b.STORE_ID WHERE b.PRODUCT_ID = 'SKU-TNT-0102'),
kit AS (
  SELECT b.STORE_ID, b.KIT_GROUP, SUM(b.LY_UNITS) AS GROUP_LY,
         MAX(n.NEEDED) AS NEEDED,
         MOD(ABS(HASH(b.STORE_ID, b.KIT_GROUP, 'kit')), 1000000) / 1000000 AS U_KIT
  FROM WILDERNESS_HOL.SETUP.GEN_INV_BASE b
  JOIN WILDERNESS_HOL.SETUP.GEN_KIT_NEED n ON n.STORE_ID = b.STORE_ID AND n.KIT_GROUP = b.KIT_GROUP
  GROUP BY 1, 2)
SELECT b.*,
  CASE
    WHEN b.PRODUCT_ID = 'SKU-TNT-0102' AND l2.STORE_ID IS NOT NULL
      THEN CEIL(b.FC + 1900 * b.WEEKLY_FC / ow.W_OVER)       -- 1,900 excess units spread by store size
    WHEN b.PRODUCT_ID = 'SKU-TNT-0102' THEN CEIL(b.FC)
    WHEN b.PRODUCT_ID = 'SKU-TNT-0103' AND l3.STORE_ID IS NOT NULL
      THEN ROUND(b.WEEKLY_FC * (4.5 + 1.5 * b.U_STOCK))      -- 4.5 to 6 weeks of cover
    WHEN b.PRODUCT_ID = 'SKU-TNT-0103' THEN CEIL(b.FC)
    WHEN b.KIT_GROUP = 'SLEEP' AND ls.STORE_ID IS NOT NULL AND k.GROUP_LY > 0
      THEN ROUND(b.LY_UNITS / k.GROUP_LY * k.NEEDED * (34.5 + 3 * k.U_KIT) / 51)   -- runs out 8-11 Dec
    -- Kit also sells outside tent baskets: everywhere else it covers 6.6 to 7.4 weeks of its own forecast,
    -- held to whole units inside the 6.5-7.5 week OK band where one exists.
    WHEN b.KIT_GROUP IN ('SLEEP','COOK','LIGHT') THEN GREATEST(CEIL(b.WEEKLY_FC * 6.5), LEAST(ROUND(b.WEEKLY_FC * (6.6 + 0.8 * b.U_STOCK)), FLOOR(b.WEEKLY_FC * 7.5)))
    -- Tents ordered 40% deep; never under 6.6 weeks, so the only tent stockout is the Summit 3P signal.
    WHEN b.CATEGORY = 'Tents & Shelters' THEN GREATEST(ROUND(b.LY_UNITS * 1.4), CEIL(b.WEEKLY_FC * 6.6))
    WHEN b.IN_CHRISTMAS_CATALOGUE THEN GREATEST(CEIL(b.WEEKLY_FC * 6.5), LEAST(ROUND(b.WEEKLY_FC * (6.6 + 0.8 * b.U_STOCK)), FLOOR(b.WEEKLY_FC * 7.5)))
    ELSE ROUND(b.LY_UNITS * (0.9 + 0.4 * b.U_STOCK)) + MOD(ABS(HASH(b.STORE_ID, b.PRODUCT_ID, 'floor')), 4)
  END AS STOCK,
  l2.STORE_ID IS NOT NULL AS IS_OVER_2P
FROM WILDERNESS_HOL.SETUP.GEN_INV_BASE b
CROSS JOIN over_w ow
LEFT JOIN lists l2 ON l2.LIST = 'OVER_2P' AND l2.STORE_ID = b.STORE_ID
LEFT JOIN lists l3 ON l3.LIST = 'SHORT_3P' AND l3.STORE_ID = b.STORE_ID
LEFT JOIN lists ls ON ls.LIST = 'SHORT_SLEEP' AND ls.STORE_ID = b.STORE_ID
LEFT JOIN kit k ON k.STORE_ID = b.STORE_ID AND k.KIT_GROUP = b.KIT_GROUP;

CREATE OR REPLACE TABLE WILDERNESS_HOL.RAW.FCT_INVENTORY AS
WITH s AS (
  SELECT g.*,
    ROUND(g.STOCK * CASE WHEN g.CATEGORY = 'Tents & Shelters' THEN 0.20
                         WHEN g.KIT_GROUP IN ('SLEEP','COOK','LIGHT') THEN 0.15 ELSE 0.10 END) AS ON_ORDER
  FROM WILDERNESS_HOL.SETUP.GEN_INV_STOCK g),
rows_ AS (
  -- Everything except Summit 2P: one row, latest tent batch code on tents.
  SELECT STORE_ID, PRODUCT_ID, IFF(CATEGORY = 'Tents & Shelters', 'B26-09', NULL) AS BATCH_CODE,
         STOCK - ON_ORDER AS ON_HAND, ON_ORDER, AVG_WEEKLY
  FROM s WHERE PRODUCT_ID <> 'SKU-TNT-0102'
  UNION ALL
  -- SIGNAL (the way out): Summit 2P B26-07 on hand is 40% of each overstocked store's excess,
  -- and 40% of on hand elsewhere. B26-07 did not exist last Christmas, so its row carries no LY rate.
  SELECT STORE_ID, PRODUCT_ID, 'B26-07',
         IFF(IS_OVER_2P, ROUND(0.40 * (STOCK - FC)), ROUND(0.40 * (STOCK - ON_ORDER))), 0, 0
  FROM s WHERE PRODUCT_ID = 'SKU-TNT-0102'
  UNION ALL
  SELECT STORE_ID, PRODUCT_ID, 'B26-02',
         STOCK - ON_ORDER - IFF(IS_OVER_2P, ROUND(0.40 * (STOCK - FC)), ROUND(0.40 * (STOCK - ON_ORDER))),
         ON_ORDER, AVG_WEEKLY
  FROM s WHERE PRODUCT_ID = 'SKU-TNT-0102')
SELECT '2026-11-03'::DATE AS SNAPSHOT_DATE, STORE_ID, PRODUCT_ID, BATCH_CODE,
       ON_HAND::NUMBER(10,0) AS ON_HAND_UNITS, ON_ORDER::NUMBER(10,0) AS ON_ORDER_UNITS,
       AVG_WEEKLY::NUMBER(10,2) AS AVG_WEEKLY_UNITS_LY_XMAS,
       ROUND((ON_HAND + ON_ORDER) / NULLIF(AVG_WEEKLY, 0), 1)::NUMBER(10,1) AS WEEKS_OF_COVER
FROM rows_
ORDER BY STORE_ID, PRODUCT_ID, BATCH_CODE;

-- -------------------------------------------------------------------------------------
-- 9. Clean up helpers and log
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_CATEGORY;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_PRODUCT;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_DAY_PICK;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_STORE_PICK;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_CAT_PICK;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_PROD_PICK;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_ORDERS;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_LINES;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_INV_BASE;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_KIT_NEED;
DROP TABLE IF EXISTS WILDERNESS_HOL.SETUP.GEN_INV_STOCK;

CALL WILDERNESS_HOL.SETUP.LOG_STEP('STRUCTURED_DATA', 'OK',
  (SELECT COUNT(*) FROM WILDERNESS_HOL.RAW.FCT_SALES_LINE));
