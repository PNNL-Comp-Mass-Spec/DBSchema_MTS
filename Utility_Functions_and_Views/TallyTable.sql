-- A Tally table that produces 1,000 rows
SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
FROM (VALUES(0),(0),(0),(0),(0),(0),(0),(0),(0),(0)) a(n)               
CROSS JOIN (VALUES(0),(0),(0),(0),(0),(0),(0),(0),(0),(0)) b(n)
CROSS JOIN (VALUES(0),(0),(0),(0),(0),(0),(0),(0),(0),(0)) c(n)
