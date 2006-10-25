/****** Object:  Table [dbo].[T_MT_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MT_Database_List](
	[MTL_ID] [int] NOT NULL,
	[MTL_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[MTL_Description] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MTL_Organism] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MTL_Campaign] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MTL_Connection_String] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MTL_NetSQL_Conn_String] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MTL_NetOleDB_Conn_String] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MTL_State] [int] NULL,
	[MTL_Update_Schedule] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MTL_Last_Update] [datetime] NULL,
	[MTL_Last_Import] [datetime] NULL,
	[MTL_Import_Holdoff] [int] NULL CONSTRAINT [DF_T_MT_Database_List_MTL_Import_Holdoff]  DEFAULT (48),
	[MTL_Created] [datetime] NOT NULL CONSTRAINT [DF_T_MT_Database_List_MTL_Created]  DEFAULT (getdate()),
	[MTL_Demand_Import] [tinyint] NULL,
	[MTL_Max_Jobs_To_Process] [int] NULL CONSTRAINT [DF_T_MT_Database_List_MTL_Max_Jobs_To_Process]  DEFAULT (500),
	[MTL_DB_Schema_Version] [real] NOT NULL CONSTRAINT [DF_T_MT_Database_List_MTL_DB_Schema_Version]  DEFAULT (2.0),
 CONSTRAINT [PK_T_MT_Database_List] PRIMARY KEY CLUSTERED 
(
	[MTL_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_MT_Database_List] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_MT_Database_List] ON [dbo].[T_MT_Database_List] 
(
	[MTL_Name] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_MT_Database_List]  WITH NOCHECK ADD  CONSTRAINT [FK_T_MT_Database_List_T_MT_Database_State_Name] FOREIGN KEY([MTL_State])
REFERENCES [T_MT_Database_State_Name] ([ID])
GO
ALTER TABLE [dbo].[T_MT_Database_List] CHECK CONSTRAINT [FK_T_MT_Database_List_T_MT_Database_State_Name]
GO
