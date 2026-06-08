SELECT * FROM financial_master
LIMIT 5;

ALTER TABLE financial_master
RENAME COLUMN opm TO operating_profit_margin;

--  PROFITABILITY & MARGINS
-- Q1. Kon si industries mein OPM (Operating Profit Margin) consistently 20%+ hai
-- aur kaunsi industries chronically negative margin pe chal rahi hain?

SELECT 
	industry,
	ROUND(AVG(operating_profit_margin)::numeric,2) AS avg_margin,
	CASE
		WHEN AVG(operating_profit_margin) > 20 THEN 'High Performer'
		WHEN AVG(operating_profit_margin) < 0 THEN 'Loss making'
		ELSE 'Average Performer'
	END AS category
FROM financial_master
GROUP BY industry
HAVING AVG(operating_profit_margin) > 20 
OR AVG(operating_profit_margin) < 0 
ORDER BY avg_margin DESC;

-- Q2. ROCE (Return on Capital Employed) 3-year average ke basis pe —
-- top 10 aur bottom 10 companies kaun hain, aur unka sector kya hai?

(SELECT
	name,
	industry,
	roce3yr_avg,
	'TOP 10' AS category
FROM financial_master
WHERE roce3yr_avg IS NOT NULL
ORDER BY roce3yr_avg DESC
LIMIT 10)
UNION ALL
(SELECT
	name,
	industry,
	roce3yr_avg,
	'BOTTOM 10' AS category
FROM financial_master
WHERE roce3yr_avg IS NOT NULL
ORDER BY roce3yr_avg ASC
LIMIT 10)
ORDER BY roce3yr_avg DESC;

	-- Q3. Companies jinka Profit After Tax positive hai lekin Net Profit negative 
	--     kitni hain?
SELECT
	name,
	industry,
	profit_after_tax,
	net_profit,
	ROUND((net_profit - profit_after_tax)::numeric,2) AS diffrence
FROM financial_master
WHERE profit_after_tax > 0 
AND net_profit < 0
ORDER BY diffrence ASC ;

--  GROWTH TRENDS
-- Q4. Sales growth 3Y vs 5Y vs 10Y compare karo —
-- kaunsi companies ka growth decelerate ho raha hai (3Y > 5Y > 10Y wali companies)?
SELECT
	name,
	industry,
	sales_growth_3years,
	sales_growth_5years,
	sales_growth_10years
FROM financial_master
WHERE sales_growth_3years < sales_growth_5years
AND sales_growth_5years < sales_growth_10years
AND sales_growth_10years >0
ORDER BY sales_growth_3years ASC ;

-- Q5. Profit Growth aur EPS Growth mein divergence kahan hai?
-- Matlab profit badhta hai but EPS nahi — dilution toh nahi ho rahi?
SELECT
	name,
	industry,
	profit_growth_3years,
	eps_growth_3years,
	ROUND((profit_growth_3years - eps_growth_3years)::numeric,2) AS divergence
FROM financial_master
WHERE profit_growth_3years >0
AND eps_growth_3years < profit_growth_3years
ORDER BY divergence DESC
LIMIT 20;

SELECT
	name,
	industry,
	profit_growth_5years,
	eps_growth_5years,
	ROUND((profit_growth_5years - eps_growth_5years)::numeric,2) AS divergence
FROM financial_master
WHERE profit_growth_5years >0
AND eps_growth_5years < profit_growth_5years
ORDER BY divergence DESC
LIMIT 20;

-- Q6. Kaunse sectors mein 10-year sustainable growth 
-- (sales + profit + EPS teeno 10Y positive) dikhta hai?
SELECT
	industry,
	COUNT(*) AS total_companies,
	ROUND(AVG(sales_growth_10years)::numeric,2) AS avg_sales_growth,
	ROUND(AVG(profit_growth_10years)::numeric,2) AS avg_profit_growth,
	ROUND(AVG(eps_growth_10years)::numeric,2) AS avg_eps_growth
FROM financial_master
WHERE sales_growth_10years> 0
AND profit_growth_10years>0
AND eps_growth_10years>0
GROUP BY industry
ORDER BY avg_profit_growth DESC;

-- VALUATION
-- Q7. EV/EBITDA 10x se kam aur ROCE 15%+ wali companies — yeh value picks hain, 
-- kitni hain aur kaunse sectors mein hain?
SELECT
	industry,
	COUNT(*) AS value_pick_companies,
	ROUND(AVG(evebitda)::numeric,2) AS avg_evebitda,
	ROUND(AVG(return_on_capital_employed)::numeric,2) AS avg_roce
FROM financial_master
WHERE evebitda <10
AND evebitda >0
AND return_on_capital_employed >15
GROUP BY industry
ORDER BY value_pick_companies DESC;

-- Q8. Price-to-Sales ratio vs Market Cap-to-Sales mein significant difference wali companies 
-- kya koi accounting anomaly hai?
SELECT
	name,
	industry,
	price_to_sales,
	market_cap_to_sales,
	ROUND(ABS(price_to_sales - market_cap_to_sales)::numeric,2) AS diffrence 
FROM financial_master
WHERE price_to_Sales IS NOT NULL
AND market_cap_to_sales IS NOT NULL
AND ABS(price_to_sales - market_cap_to_sales)>5
ORDER BY diffrence DESC
LIMIT 20;

-- Q9. Intrinsic Value vs Current Price compare karo — 
-- kitni companies 30%+ undervalued hain? Aur kitni 2x+ overvalued?
SELECT
	name,
	industry,
	current_price,
	intrinsic_value,
	ROUND(((current_price - intrinsic_value )/ intrinsic_value * 100)
	::numeric,2) AS premium_discount_pct,
	CASE
		WHEN current_price < intrinsic_value *0.70 THEN 'Undervalue'
		WHEN current_price > intrinsic_value * 2 THEN 'Overvalued '
		ELSE 'Fair Value'
	END AS status
FROM financial_master
WHERE intrinsic_value > 0 
AND current_price > 0
ORDER BY premium_discount_pct DESC;

-- Q11. PEG Ratio 1 se kam wali high-growth companies kaun si hain? (Growth at a reasonable price)
SELECT
	name,
	industry,
	peg_ratio,
	eps,
	current_price
FROM financial_master
WHERE peg_ratio >0
AND peg_ratio <1
ORDER BY peg_ratio ASC
LIMIT 20;

-- DEBT & FINANCIAL HEALTH
-- Q12. Debt-to-Profit ratio 5x se zyada wali companies — 
-- kitni hain aur kaunse sectors mein concentrated hain? Yeh distressed assets hain?
SELECT
	industry,
	COUNT(*) AS Distressed_company,
	ROUND(AVG(debt_to_profit)::numeric,2) AS avg_debt_to_profit
FROM financial_master
WHERE debt_To_profit > 5
GROUP BY industry
ORDER BY distressed_company ASC;

-- Q13. Interest Coverage Ratio 1.5x se kam wali companies — 
-- inhe toh interest dena bhi mushkil hai, kya default risk hai?
SELECT
	industry,
	COUNT(*) AS at_risk_companies,
	ROUND(AVG(interest_coverage_ratio)::numeric,2) AS avg_icr
FROM financial_master
WHERE interest_coverage_ratio > 0
AND interest_coverage_ratio <1.5
GROUP BY industry
ORDER BY at_risk_companies ASC;

-- Q14. Altman Z-Score distribution kya hai?
-- "Distress zone" (Z < 1.81) mein kitni companies hain?
SELECT
	CASE 
		WHEN altman_z_score <1.81 THEN 'Distress Zone'
		WHEN altman_z_score BETWEEN 1.80 AND 3 THEN 'Grey Zone'
		WHEN altman_z_score > 3 THEN 'Safe Zone'
	END AS zone,
	COUNT(*) as total_companies
FROM financial_master
WHERE altman_z_score IS NOT NULL
GROUP BY zone
ORDER BY total_companies DESC;

SELECT
	name,
	industry,
	altman_z_score
FROM financial_master
WHERE altman_z_score < 1.81 
ORDER BY altman_z_score ASC
LIMIT 20;

-- Q15. Current Ratio < 1 (liquidity crisis) + high debt combination wali 
-- companies — yeh red flag hai, kaun kaun si hain?
SELECT
    name,
    industry,
    current_ratio,
    debt,
    net_worth
FROM financial_master
WHERE current_ratio < 1
    AND current_ratio > 0
    AND debt > 0
    AND net_worth > 0
    AND debt > net_worth
ORDER BY current_ratio ASC;

-- INDUSTRY-LEVEL INSIGHTS
-- Q16. Industry-wise median OPM, ROCE, aur Debt-to-Profit — 
-- kaunsa sector fundamentally sabse strong hai?
SELECT
	industry,
	COUNT(*) AS total_companies,
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP 
	(ORDER BY operating_profit_margin)::numeric,2) AS medium_opm,
	ROUND(PERCENTILE_CONT(0.5)WITHIN GROUP 
	(ORDER BY return_on_capital_employed)::numeric,2) AS median_roce,
	ROUND(PERCENTILE_CONT(0.5)WITHIN GROUP 
	(ORDER BY debt_to_profit)::numeric,2) AS median_debt_to_profit
FROM financial_master
GROUP BY industry
ORDER BY median_roce DESC;

-- Q17. Finance & Investments sector mein 560 companies hain — 
-- inki average leverage aur net worth kya hai? NBFC risk kitna hai?
SELECT
	name,
	leverage,
	net_worth,
	debt,
	current_ratio,
	interest_coverage_ratio
FROM financial_master
WHERE industry ='Finance & Investments'
AND leverage IS NOT NULL
ORDER BY leverage DESC;

SELECT
	ROUND(AVG(leverage)::numeric,2) AS avg_leverage,
	ROUND(AVG(net_worth)::numeric,2) AS avg_net_worth,
	ROUND(AVG(debt)::numeric,2) AS avg_debt,
	COUNT(*) AS total_companies,
	COUNT(CASE WHEN leverage > 5 THEN 1 END ) AS high_leverage_companies
FROM financial_master
WHERE industry = 'Finance & Investments';

-- Q18. Construction sector (323 companies) ka working capital aur current ratio kaisa
-- hai? Kya sector mein liquidity stress hai?
SELECT
    name,
    current_ratio,
    working_capital,
    debt,
    interest_coverage_ratio
FROM financial_master
WHERE industry = 'Construction'
ORDER BY current_ratio ASC;

SELECT
    COUNT(*) AS total_companies,
    COUNT(CASE WHEN current_ratio < 1 THEN 1 END) AS liquidity_stressed,
    ROUND(AVG(current_ratio)::numeric, 2) AS avg_current_ratio,
    ROUND(AVG(working_capital)::numeric, 2) AS avg_working_capital
FROM financial_master
WHERE industry = 'Construction';

-- CASH & WORKING CAPITAL
-- Q19. Cash Equivalents vs Total Debt ratio — "cash-rich, debt-free" 
-- companies kaun si hain? Yeh recession-proof hain?
SELECT
	name,
	industry,
	cash_equivalents,
	debt,
	ROUND((cash_equivalents - debt)::numeric,2) AS net_cash
FROM financial_master
WHERE cash_equivalents > debt
AND debt >= 0
ORDER BY net_cash DESC
LIMIT 20;

-- Q20. Negative Working Capital wali companies — kaunse sectors mein yeh common 
-- hai aur kya yeh good (like FMCG) ya bad sign hai?
SELECT
	industry,
	COUNT(*) AS total_companies,
	COUNT(CASE WHEN working_capital < 0 THEN 1 END ) AS negative_wc_companies,
	ROUND(AVG(working_capital)::numeric,2) AS avg_working_capital
FROM financial_master
GROUP BY industry
HAVING COUNT(CASE WHEN working_capital < 0 THEN 1 END ) >0
ORDER BY negative_wc_companies DESC;

-- RISK & RED FLAGS
-- Q21. Companies jinke 3 ya zyada red flags hain simultaneously — negative 
-- OPM + high debt + low ROCE + negative growth. Kitni hain?
SELECT *
FROM (
    SELECT
        name,
        industry,
        operating_profit_margin,
        debt_to_profit,
        return_on_capital_employed,
        sales_growth_3years,
        (
            CASE WHEN operating_profit_margin < 0 THEN 1 ELSE 0 END +
            CASE WHEN debt_to_profit > 5 THEN 1 ELSE 0 END +
            CASE WHEN return_on_capital_employed < 0 THEN 1 ELSE 0 END +
            CASE WHEN sales_growth_3years < 0 THEN 1 ELSE 0 END
        ) AS red_flag_count
    FROM financial_master
) AS subquery
WHERE red_flag_count >= 3
ORDER BY red_flag_count DESC;

-- Q22. Sales negative (-20 to 0) wali companies — kya yeh data quality issue hai ya 
-- genuinely revenue negative companies hain?
SELECT
	name,
	industry,
	sales,
	operating_profit,
	net_profit
FROM financial_master
WHERE sales< 0
ORDER BY sales ASC;

SELECT
    COUNT(*) AS negative_sales_companies,
    industry
FROM financial_master
WHERE sales < 0
GROUP BY industry
ORDER BY negative_sales_companies DESC;

-- Q23. EPS negative wali companies ka market cap kya hai? Koi zombie companies toh 
-- nahi hain jo loss pe chal rahi hain fir bhi overvalued hain?
SELECT
	name,
	industry,
	eps,
	market_capitalization,
	current_price,
	net_profit
FROM financial_master
WHERE eps<0
AND market_capitalization > 1000
ORDER BY market_capitalization DESC
LIMIT 20;

-- Q24. Agar ek "Quality Growth" screener banao — ROCE > 15%, Profit 
-- Growth 5Y > 15%, Debt-to-Profit < 3, Current Ratio > 1.5 — kitni companies pass karti hain aur kaunsi?
SELECT
	name,
	industry,
	return_on_capital_employed,
	profit_growth_5years,
	debt_to_profit,
	current_ratio
FROM financial_master
WHERE return_on_Capital_employed >15
AND profit_growth_5years >15 
AND debt_to_profit < 3 
AND current_ratio > 1.5
ORDER BY return_on_capital_employed DESC;

SELECT
	industry,
	COUNT(*) AS quality_companies
FROM financial_master
WHERE return_on_Capital_employed >15
AND profit_growth_5years >15 
AND debt_to_profit < 3 
AND current_ratio > 1.5
GROUP BY industry
ORDER BY quality_companies DESC;

-- Q25. Sector rotation perspective se — kaunse sectors mein valuation 
-- (EV/EBITDA) abhi bhi reasonable hai aur fundamentals strong hain? Next 3-5 year ka best bet kya hai?
SELECT
	industry,
	COUNT(*) AS total_companies,
	ROUND(AVG(evebitda)::numeric,2) AS avg_evebitda,
	ROUND(AVG(return_on_capital_employed)::numeric,2) AS avg_roce,
	ROUND(AVG(sales_growth_5years)::numeric,2) AS avg_sales_growth_5y,
	ROUND(AVG(profit_growth_5years)::numeric,2 ) AS avg_profit_growth_5y
FROM financial_master
WHERE evebitda>0
AND evebitda<15
AND return_on_capital_employed >12
AND sales_growth_5years >10
AND profit_growth_5years >10
GROUP BY industry
ORDER BY avg_roce DESC;

















	