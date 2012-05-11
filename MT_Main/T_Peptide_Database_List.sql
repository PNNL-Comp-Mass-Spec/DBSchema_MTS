/****** Object:  Table [dbo].[T_Peptide_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peptide_Database_List](
	[PDB_ID] [int] NOT NULL,
	[PDB_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[PDB_Description] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PDB_Organism] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[PDB_Connection_String] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PDB_NetSQL_Conn_String] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PDB_NetOleDB_Conn_String] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PDB_State] [int] NULL,
	[PDB_Last_Update] [datetime] NULL,
	[PDB_Last_Import] [datetime] NULL,
	[PDB_Import_Holdoff] [int] NULL,
	[PDB_Created] [datetime] NOT NULL,
	[PDB_Demand_Import] [tinyint] NULL,
	[PDB_Max_Jobs_To_Process] [int] NULL,
	[PDB_DB_Schema_Version] [real] NOT NULL,
 CONSTRAINT [PK_T_Peptide_Database_List] PRIMARY KEY CLUSTERED 
(
	[PDB_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Peptide_Database_List] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Peptide_Database_List] ON [dbo].[T_Peptide_Database_List] 
(
	[PDB_Name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
/****** Object:  Trigger [dbo].[trig_d_Peptide_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




CREATE Trigger [dbo].[trig_d_Peptide_Database_List] on [dbo].[T_Peptide_Database_List]
For Delete
/****************************************************
**
**	Desc: 
**		Makes an entry in T_Event_Log for the deleted PT database
**
**	Auth:	mem
**	Date:	08/10/2007
**    
*****************************************************/
AS
	-- Add entries to T_Event_Log for each job deleted from T_Peptide_Database_List
	INSERT INTO T_Event_Log
		(
			Target_Type, Target_ID, 
			Target_State, Prev_Target_State, 
			Entered
		)
	SELECT	2 AS Target_Type, PDB_ID, 
			0 AS Target_State, PDB_State, 
			GETDATE()
	FROM deleted
	ORDER BY PDB_ID


GO
/****** Object:  Trigger [dbo].[trig_i_Peptide_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Trigger trig_i_Peptide_Database_List on T_Peptide_Database_List
For Insert
/****************************************************
**
**	Desc: 
**		Makes an entry in T_Event_Log for the new PT database
**
**	Auth:	mem
**	Date:	08/10/2007
**    
*****************************************************/
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 2, inserted.PDB_ID, inserted.PDB_State, 0, GetDate()
	FROM inserted


GO
/****** Object:  Trigger [dbo].[trig_u_Peptide_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Trigger trig_u_Peptide_Database_List on T_Peptide_Database_List
For Update
/****************************************************
**
**	Desc: 
**		Makes an entry in T_Event_Log for the updated PT database
**
**	Auth:	mem
**	Date:	08/10/2007
**    
*****************************************************/
AS
	If @@RowCount = 0
		Return

	if update(PDB_State)
		INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
		SELECT 2, inserted.PDB_ID, inserted.PDB_State, deleted.PDB_State, GetDate()
		FROM deleted INNER JOIN inserted ON deleted.PDB_ID = inserted.PDB_ID


GO
ALTER TABLE [dbo].[T_Peptide_Database_List]  WITH CHECK ADD  CONSTRAINT [FK_T_Peptide_Database_List_T_MT_Database_State_Name] FOREIGN KEY([PDB_State])
REFERENCES [T_MT_Database_State_Name] ([ID])
GO
ALTER TABLE [dbo].[T_Peptide_Database_List] CHECK CONSTRAINT [FK_T_Peptide_Database_List_T_MT_Database_State_Name]
GO
ALTER TABLE [dbo].[T_Peptide_Database_List] ADD  CONSTRAINT [DF_T_Peptide_Database_List_PDB_Import_Holdoff]  DEFAULT (24) FOR [PDB_Import_Holdoff]
GO
ALTER TABLE [dbo].[T_Peptide_Database_List] ADD  CONSTRAINT [DF_T_Peptide_Database_List_PDB_Created]  DEFAULT (getdate()) FOR [PDB_Created]
GO
ALTER TABLE [dbo].[T_Peptide_Database_List] ADD  CONSTRAINT [DF_T_Peptide_Database_List_PDB_Demand_Import]  DEFAULT (0) FOR [PDB_Demand_Import]
GO
ALTER TABLE [dbo].[T_Peptide_Database_List] ADD  CONSTRAINT [DF_T_Peptide_Database_List_PDB_Max_Jobs_To_Process]  DEFAULT (50) FOR [PDB_Max_Jobs_To_Process]
GO
ALTER TABLE [dbo].[T_Peptide_Database_List] ADD  CONSTRAINT [DF_T_Peptide_Database_List_PDB_DB_Schema_Version]  DEFAULT (2) FOR [PDB_DB_Schema_Version]
GO
