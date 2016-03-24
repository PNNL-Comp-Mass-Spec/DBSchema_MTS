/****** Object:  Table [AlertSettings] ******/
/****** RowCount: 32 ******/
/****** Columns: AlertName, VariableName, Enabled, Value, Description ******/
INSERT INTO [AlertSettings] VALUES ('BlockingAlert','QueryValue','True','10','Value is in seconds')
INSERT INTO [AlertSettings] VALUES ('BlockingAlert','QueryValue2','True','20','Value is in seconds')
INSERT INTO [AlertSettings] VALUES ('CPUAlert','QueryValue','True','85','Value is in percentage')
INSERT INTO [AlertSettings] VALUES ('CPUAlert','QueryValue2','True','95','Value is in percentage')
INSERT INTO [AlertSettings] VALUES ('HealthReport','MaxDeadLockRows','True','250','Maximum Deadlock rows to display')
INSERT INTO [AlertSettings] VALUES ('HealthReport','MaxErrorLogRows','True','250','Maximum Error Log rows to display')
INSERT INTO [AlertSettings] VALUES ('HealthReport','MinLogFileSizeMB','True','100','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowAllDisks','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowBackups','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowCPUStats','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowDatabaseSettings','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowdbaSettings','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowEmptySections','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowErrorLog','True','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowFullDBList','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowFullFileInfo','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowFullJobInfo','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowLogBackups','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowModifiedServerConfig','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowOrphanedUsers','False','0','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowPerfStats','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('HealthReport','ShowSchemaChanges','False','','Variable for the HealthReport')
INSERT INTO [AlertSettings] VALUES ('LogFiles','MinFileSizeMB','True','100','Ignore LogFiles smaller than this threshold, in MB')
INSERT INTO [AlertSettings] VALUES ('LogFiles','QueryValue','True','50','Value is in percentage')
INSERT INTO [AlertSettings] VALUES ('LogFiles','QueryValue2','True','20','Value is in percentage')
INSERT INTO [AlertSettings] VALUES ('LongRunningJobs','QueryValue','True','60','Value is in seconds')
INSERT INTO [AlertSettings] VALUES ('LongRunningQueries','Exclusion_Sql','True','sqlBackup','SQL Like Clause')
INSERT INTO [AlertSettings] VALUES ('LongRunningQueries','QueryValue','True','615','Value is in seconds')
INSERT INTO [AlertSettings] VALUES ('LongRunningQueries','QueryValue2','True','1200','Value is in seconds')
INSERT INTO [AlertSettings] VALUES ('TempDB','MinFileSizeMB','True','100','Ignore the tempDB if the log file size is below this threshold, in MB')
INSERT INTO [AlertSettings] VALUES ('TempDB','QueryValue','True','50','Value is in percentage')
INSERT INTO [AlertSettings] VALUES ('TempDB','QueryValue2','True','20','Value is in percentage')
