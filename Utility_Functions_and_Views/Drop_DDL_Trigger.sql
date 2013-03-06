IF EXISTS (SELECT * FROM sys.triggers WHERE parent_class_desc = 'DATABASE' AND name = N'trig_LogDDLEvent')
	DISABLE TRIGGER [trig_LogDDLEvent] ON DATABASE
go

/****** Object:  DdlTrigger [trig_LogDDLEvent]    Script Date: 08/29/2007 12:37:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF EXISTS (SELECT * FROM sys.triggers WHERE parent_class_desc = 'DATABASE' AND name = N'trig_LogDDLEvent')
Begin
	SELECT 'Delete trigger from ' + DB_NAME()
	drop trigger trig_LogDDLEvent ON database
End