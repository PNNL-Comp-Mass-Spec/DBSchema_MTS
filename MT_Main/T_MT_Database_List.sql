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
	[MTL_Last_Update] [datetime] NULL,
	[MTL_Last_Import] [datetime] NULL,
	[MTL_Import_Holdoff] [int] NULL,
	[MTL_Created] [datetime] NOT NULL,
	[MTL_Demand_Import] [tinyint] NULL,
	[MTL_Max_Jobs_To_Process] [int] NULL,
	[MTL_DB_Schema_Version] [real] NOT NULL,
 CONSTRAINT [PK_T_MT_Database_List] PRIMARY KEY CLUSTERED 
(
	[MTL_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_MT_Database_List] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_MT_Database_List] ON [dbo].[T_MT_Database_List]
(
	[MTL_Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_MT_Database_List] ADD  CONSTRAINT [DF_T_MT_Database_List_MTL_Import_Holdoff]  DEFAULT ((12)) FOR [MTL_Import_Holdoff]
GO
ALTER TABLE [dbo].[T_MT_Database_List] ADD  CONSTRAINT [DF_T_MT_Database_List_MTL_Created]  DEFAULT (getdate()) FOR [MTL_Created]
GO
ALTER TABLE [dbo].[T_MT_Database_List] ADD  CONSTRAINT [DF_T_MT_Database_List_MTL_Max_Jobs_To_Process]  DEFAULT (500) FOR [MTL_Max_Jobs_To_Process]
GO
ALTER TABLE [dbo].[T_MT_Database_List] ADD  CONSTRAINT [DF_T_MT_Database_List_MTL_DB_Schema_Version]  DEFAULT (2.0) FOR [MTL_DB_Schema_Version]
GO
ALTER TABLE [dbo].[T_MT_Database_List]  WITH CHECK ADD  CONSTRAINT [FK_T_MT_Database_List_T_MT_Database_State_Name] FOREIGN KEY([MTL_State])
REFERENCES [dbo].[T_MT_Database_State_Name] ([ID])
GO
ALTER TABLE [dbo].[T_MT_Database_List] CHECK CONSTRAINT [FK_T_MT_Database_List_T_MT_Database_State_Name]
GO
/****** Object:  Trigger [dbo].[trig_d_MT_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE Trigger [dbo].[trig_d_MT_Database_List] on [dbo].[T_MT_Database_List]
For Delete
/****************************************************
**
**	Desc: 
**		Makes an entry in T_Event_Log for the deleted MT database
**
**	Auth:	mem
**	Date:	08/10/2007
**    
*****************************************************/
AS
	-- Add entries to T_Event_Log for each job deleted from T_MT_Database_List
	INSERT INTO T_Event_Log
		(
			Target_Type, Target_ID, 
			Target_State, Prev_Target_State, 
			Entered
		)
	SELECT	1 AS Target_Type, MTL_ID, 
			0 AS Target_State, MTL_State, 
			GETDATE()
	FROM deleted
	ORDER BY MTL_ID


GO
/****** Object:  Trigger [dbo].[trig_i_MT_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE Trigger trig_i_MT_Database_List on T_MT_Database_List
For Insert
/****************************************************
**
**	Desc: 
**		Makes an entry in T_Event_Log for the new MT database
**
**	Auth:	mem
**	Date:	08/10/2007
**    
*****************************************************/
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 1, inserted.MTL_ID, inserted.MTL_State, 0, GetDate()
	FROM inserted


GO
/****** Object:  Trigger [dbo].[trig_u_MT_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE Trigger trig_u_MT_Database_List on T_MT_Database_List
For Update
/****************************************************
**
**	Desc: 
**		Makes an entry in T_Event_Log for the updated MT database
**
**	Auth:	mem
**	Date:	08/10/2007
**    
*****************************************************/
AS
	If @@RowCount = 0
		Return

	if update(MTL_State)
		INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
		SELECT 1, inserted.MTL_ID, inserted.MTL_State, deleted.MTL_State, GetDate()
		FROM deleted INNER JOIN inserted ON deleted.MTL_ID = inserted.MTL_ID


GO
