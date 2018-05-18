/****** Object:  View [dbo].[BlitzFirst_FileStats2_Deltas] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[BlitzFirst_FileStats2_Deltas] AS 
WITH RowDates as
(
        SELECT 
                ROW_NUMBER() OVER (ORDER BY [CheckDate]) ID,
                [CheckDate]
        FROM [dbo].[BlitzFirst_FileStats2]
        GROUP BY [CheckDate]
),
CheckDates as
(
        SELECT ThisDate.CheckDate,
               LastDate.CheckDate as PreviousCheckDate
        FROM RowDates ThisDate
        JOIN RowDates LastDate
        ON ThisDate.ID = LastDate.ID + 1
)
     SELECT f.ServerName,
            f.CheckDate,
            f.DatabaseID,
            f.DatabaseName,
            f.FileID,
            f.FileLogicalName,
            f.TypeDesc,
            f.PhysicalName,
            f.SizeOnDiskMB,
            DATEDIFF(ss, fPrior.CheckDate, f.CheckDate) AS ElapsedSeconds,
            (f.SizeOnDiskMB - fPrior.SizeOnDiskMB) AS SizeOnDiskMBgrowth,
            (f.io_stall_read_ms - fPrior.io_stall_read_ms) AS io_stall_read_ms,
            io_stall_read_ms_average = CASE
                                           WHEN(f.num_of_reads - fPrior.num_of_reads) = 0
                                           THEN 0
                                           ELSE(f.io_stall_read_ms - fPrior.io_stall_read_ms) /     (f.num_of_reads   -           fPrior.num_of_reads)
                                       END,
            (f.num_of_reads - fPrior.num_of_reads) AS num_of_reads,
            (f.bytes_read - fPrior.bytes_read) / 1024.0 / 1024.0 AS megabytes_read,
            (f.io_stall_write_ms - fPrior.io_stall_write_ms) AS io_stall_write_ms,
            io_stall_write_ms_average = CASE
                                            WHEN(f.num_of_writes - fPrior.num_of_writes) = 0
                                            THEN 0
                                            ELSE(f.io_stall_write_ms - fPrior.io_stall_write_ms) /         (f.num_of_writes   -       fPrior.num_of_writes)
                                        END,
            (f.num_of_writes - fPrior.num_of_writes) AS num_of_writes,
            (f.bytes_written - fPrior.bytes_written) / 1024.0 / 1024.0 AS megabytes_written
     FROM   [dbo].[BlitzFirst_FileStats2] f
            INNER HASH JOIN CheckDates DATES ON f.CheckDate = DATES.CheckDate
            INNER JOIN [dbo].[BlitzFirst_FileStats2] fPrior ON f.ServerName =                 fPrior.ServerName
                                                              AND f.DatabaseID = fPrior.DatabaseID
                                                              AND f.FileID = fPrior.FileID
                                                              AND fPrior.CheckDate =   DATES.PreviousCheckDate

     WHERE  f.num_of_reads >= fPrior.num_of_reads
            AND f.num_of_writes >= fPrior.num_of_writes
            AND DATEDIFF(MI, fPrior.CheckDate, f.CheckDate) BETWEEN 1 AND 60;
GO
