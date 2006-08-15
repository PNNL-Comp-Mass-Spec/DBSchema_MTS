/****** Object:  Table [T_Status] ******/
/****** RowCount: 5 ******/
/****** Columns: statuskey, name, description ******/
INSERT INTO [T_Status] VALUES (1,'new','Job has been requested but is not yet being worked.')
INSERT INTO [T_Status] VALUES (2,'working','Job is being processed.')
INSERT INTO [T_Status] VALUES (3,'complete','Job has been successfully completed.')
INSERT INTO [T_Status] VALUES (4,'failed','Job has not been completed successfully.')
INSERT INTO [T_Status] VALUES (5,'paused','Job is not ready to be worked, but has not been completed.')
