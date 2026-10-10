USE Toy;
GO


/* =========================================================
   STEP 1 — Check the overall session date range
   ========================================================= */

SELECT
    MIN(created_at) AS FirstSession,
    MAX(created_at) AS LastSession
FROM dbo.winter_sessions;


/* =========================================================
   STEP 2 — Inspect the pageview table structure
   ========================================================= */

EXEC sp_help 'dbo.winter_pageviews';


/* =========================================================
   STEP 3 — Explore available landing/page URLs
   ========================================================= */

SELECT
    pageview_url,
    COUNT(*) AS Pageviews
FROM dbo.winter_pageviews
GROUP BY pageview_url
ORDER BY Pageviews DESC;


/* =========================================================
   STEP 4 — Check when landing pages were used
   ========================================================= */

SELECT
    pageview_url,
    MIN(created_at) AS FirstSeen,
    MAX(created_at) AS LastSeen,
    COUNT(*) AS Pageviews
FROM dbo.winter_pageviews
WHERE pageview_url IN (
    '/home',
    '/lander-1',
    '/lander-2',
    '/lander-3',
    '/lander-4',
    '/lander-5'
)
GROUP BY pageview_url
ORDER BY FirstSeen;


/* =========================================================
   STEP 5 — Identify the first pageview of each session
   ========================================================= */

WITH first_pageview AS (
    SELECT
        website_session_id,
        pageview_url,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY website_session_id
            ORDER BY created_at
        ) AS rn
    FROM dbo.winter_pageviews
)
SELECT
    pageview_url,
    MIN(created_at) AS FirstLanding,
    MAX(created_at) AS LastLanding,
    COUNT(*) AS Sessions
FROM first_pageview
WHERE rn = 1
  AND pageview_url IN ('/home', '/lander-1')
GROUP BY pageview_url
ORDER BY FirstLanding;


/* =========================================================
   STEP 6 — Identify A/B test traffic
   Control = /home
   Test    = /lander-1
   ========================================================= */

WITH first_pageview AS (
    SELECT
        website_session_id,
        pageview_url,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY website_session_id
            ORDER BY created_at
        ) AS rn
    FROM dbo.winter_pageviews
)
SELECT
    pageview_url,
    COUNT(*) AS Sessions,
    MIN(created_at) AS FirstSession,
    MAX(created_at) AS LastSession
FROM first_pageview
WHERE rn = 1
  AND pageview_url IN ('/home', '/lander-1')
  AND created_at >= '2012-06-19'
  AND created_at < '2013-03-11'
GROUP BY pageview_url
ORDER BY pageview_url;



/* =========================================================
   STEP 7 — Calculate bounce rate
   ========================================================= */

WITH session_pages AS (
    SELECT
        website_session_id,
        COUNT(*) AS pageview_count
    FROM dbo.winter_pageviews
    GROUP BY website_session_id
),

first_pageview AS (
    SELECT
        website_session_id,
        pageview_url,
        created_at,
        ROW_NUMBER() OVER (
            PARTITION BY website_session_id
            ORDER BY created_at
        ) AS rn
    FROM dbo.winter_pageviews
)

SELECT
    fp.pageview_url AS landing_page,

    COUNT(*) AS total_sessions,

    SUM(
        CASE
            WHEN sp.pageview_count = 1 THEN 1
            ELSE 0
        END
    ) AS bounced_sessions,

    CAST(
        SUM(
            CASE
                WHEN sp.pageview_count = 1 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*)
        AS DECIMAL(5,2)
    ) AS bounce_rate

FROM first_pageview fp

JOIN session_pages sp
    ON fp.website_session_id = sp.website_session_id

WHERE fp.rn = 1
  AND fp.pageview_url IN ('/home', '/lander-1')
  AND fp.created_at >= '2012-06-19'
  AND fp.created_at < '2013-03-11'

GROUP BY fp.pageview_url
ORDER BY fp.pageview_url;