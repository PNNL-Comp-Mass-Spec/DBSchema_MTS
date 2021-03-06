/****** Object:  Table [dbo].[T_UMC_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_UMC_Database_List](
	[UDB_ID] [int] NOT NULL,
	[UDB_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[UDB_Description] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[UDB_Organism] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[UDB_Connection_String] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[UDB_NetSQL_Conn_String] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[UDB_NetOleDB_Conn_String] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[UDB_State] [int] NULL,
	[UDB_Update_Schedule] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[UDB_Last_Update] [datetime] NULL,
	[UDB_Last_Import] [datetime] NULL,
	[UDB_Import_Holdoff] [int] NULL,
	[UDB_Created] [datetime] NOT NULL,
	[UDB_Demand_Import] [tinyint] NULL,
	[UDB_Max_Jobs_To_Process] [int] NULL,
	[UDB_DB_Schema_Version] [real] NOT NULL,
 CONSTRAINT [PK_T_UMC_Database_List] PRIMARY KEY CLUSTERED 
(
	[UDB_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_UMC_Database_List] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_UMC_Database_List] ON [dbo].[T_UMC_Database_List]
(
	[UDB_Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_UMC_Database_List] ADD  CONSTRAINT [DF_T_UMC_Database_List_UDB_Created]  DEFAULT (getdate()) FOR [UDB_Created]
GO
ALTER TABLE [dbo].[T_UMC_Database_List] ADD  CONSTRAINT [DF_T_UMC_Database_List_UDB_Max_Jobs_To_Process]  DEFAULT (500) FOR [UDB_Max_Jobs_To_Process]
GO
ALTER TABLE [dbo].[T_UMC_Database_List] ADD  CONSTRAINT [DF_T_UMC_Database_List_UDB_DB_Schema_Version]  DEFAULT (2) FOR [UDB_DB_Schema_Version]
GO
ALTER TABLE [dbo].[T_UMC_Database_List]  WITH CHECK ADD  CONSTRAINT [FK_T_UMC_Database_List_T_MT_Database_State_Name] FOREIGN KEY([UDB_State])
REFERENCES [dbo].[T_MT_Database_State_Name] ([ID])
GO
ALTER TABLE [dbo].[T_UMC_Database_List] CHECK CONSTRAINT [FK_T_UMC_Database_List_T_MT_Database_State_Name]
GO
