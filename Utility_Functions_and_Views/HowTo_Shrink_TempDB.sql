DBCC SHRINKDATABASE(tempdb, 10); -- shrink tempdb
GO

USE tempdb
dbcc shrinkfile ('tempdev')  -- shrink db file
dbcc shrinkfile ('tempdev2') -- shrink db file (when the temp DB is split into multiple parts)
dbcc shrinkfile ('templog')  -- shrink log file
GO

-- Query to check for the temp DB having multiple primary files
SELECT name, physical_name AS current_file_location
FROM sys.master_files
WHERE name LIKE 'temp%'


