IF exists (SELECT * FROM sys.tables WHERE name = 'SchemaChangeLog')
	GRANT INSERT ON [dbo].[SchemaChangeLog] TO [pnl\svc-dms] AS [dbo]

GRANT INSERT,UPDATE ON [dbo].[T_NET_Update_Task] TO [pnl\svc-dms] AS [dbo]
GRANT INSERT,UPDATE ON [dbo].[T_NET_Update_Task_Job_Map] TO [pnl\svc-dms] AS [dbo]
GRANT UPDATE ON [dbo].[T_Analysis_Description] TO [pnl\svc-dms] AS [dbo]

EXEC sp_addrolemember N'db_ddladmin', N'pnl\svc-dms'
GO


GRANT INSERT ON [dbo].[SchemaChangeLog] TO [pnl\svc-dms] AS [dbo]
GRANT UPDATE ON [dbo].[T_Analysis_Description] TO [pnl\svc-dms] AS [dbo]
GRANT INSERT,UPDATE ON [dbo].[T_NET_Update_Task] TO [pnl\svc-dms] AS [dbo]
GRANT INSERT,UPDATE ON [dbo].[T_NET_Update_Task_Job_Map] TO [pnl\svc-dms] AS [dbo]

GRANT EXECUTE ON [dbo].[RequestGANETUpdateTask] TO [pnl\svc-dms] AS [dbo]GRANT EXECUTE ON [dbo].[SetPeptideProphetTaskComplete] TO [pnl\svc-dms] AS [dbo]GRANT EXECUTE ON [dbo].[RequestPeptideProphetTask] TO [pnl\svc-dms] AS [dbo]GRANT EXECUTE ON [dbo].[SetGANETUpdateTaskComplete] TO [pnl\svc-dms] AS [dbo]
