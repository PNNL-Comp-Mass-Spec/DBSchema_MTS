INSERT INTO dbo.T_Status
  VALUES (1, N'new', N'Job has been requested but is not yet being worked.')
INSERT INTO dbo.T_Status
  VALUES (2, N'working', N'Job is being processed.')
INSERT INTO dbo.T_Status
  VALUES (3, N'complete', N'Job has been successfully completed.')
INSERT INTO dbo.T_Status
  VALUES (4, N'failed', N'Job has not been completed successfully.')
INSERT INTO dbo.T_Status
  VALUES (5, N'paused', N'Job is not ready to be worked, but has not been completed.')

go
