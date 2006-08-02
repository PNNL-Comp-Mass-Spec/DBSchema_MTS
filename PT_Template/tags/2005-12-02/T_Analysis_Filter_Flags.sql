if exists (select * from dbo.sysobjects where id = object_id(N'[T_Analysis_Filter_Flags]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Analysis_Filter_Flags]
GO

CREATE TABLE [T_Analysis_Filter_Flags] (
	[Filter_ID] [int] NOT NULL ,
	[Job] [int] NOT NULL ,
	CONSTRAINT [PK_T_Analysis_Filter_Flags] PRIMARY KEY  CLUSTERED 
	(
		[Filter_ID],
		[Job]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Analysis_Filter_Flags_T_Analysis_Description] FOREIGN KEY 
	(
		[Job]
	) REFERENCES [T_Analysis_Description] (
		[Job]
	)
) ON [PRIMARY]
GO


