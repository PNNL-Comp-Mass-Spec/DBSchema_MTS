/****** Object:  Table [dbo].[T_Analysis_Job_to_MT_DB_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Job_to_MT_DB_Map](
	[Job] [int] NOT NULL,
	[MTL_ID] [int] NOT NULL,
	[ResultType] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Created] [datetime] NOT NULL,
	[Last_Affected] [datetime] NOT NULL,
	[Process_State] [int] NOT NULL,
 CONSTRAINT [PK_T_Analysis_Job_to_MT_DB_Map] PRIMARY KEY CLUSTERED 
(
	[Job] ASC,
	[MTL_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Analysis_Job_to_MT_DB_Map] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Analysis_Job_to_MT_DB_Map] ON [dbo].[T_Analysis_Job_to_MT_DB_Map] 
(
	[MTL_ID] ASC,
	[Job] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Analysis_Job_to_MT_DB_Map]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Analysis_Job_to_MT_DB_Map_T_MT_Database_List] FOREIGN KEY([MTL_ID])
REFERENCES [T_MT_Database_List] ([MTL_ID])
GO
ALTER TABLE [dbo].[T_Analysis_Job_to_MT_DB_Map] CHECK CONSTRAINT [FK_T_Analysis_Job_to_MT_DB_Map_T_MT_Database_List]
GO
ALTER TABLE [dbo].[T_Analysis_Job_to_MT_DB_Map] ADD  CONSTRAINT [DF_T_Analysis_Job_to_MT_DB_Map_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
