/****** Object:  Table [dbo].[T_ORF_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_ORF_Database_List](
	[ODB_ID] [int] NOT NULL,
	[ODB_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ODB_Description] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_Organism] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_Connection_String] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_NetSQL_Conn_String] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_NetOleDB_Conn_String] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_State] [int] NOT NULL,
	[Notes] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_Created] [smalldatetime] NOT NULL,
	[ODB_DB_Schema_Version] [real] NOT NULL,
	[ODB_Fasta_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_ORF_Database_List] PRIMARY KEY CLUSTERED 
(
	[ODB_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_ORF_Database_List] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_ORF_Database_List] ON [dbo].[T_ORF_Database_List] 
(
	[ODB_Name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
/****** Object:  Trigger [dbo].[trig_d_ORF_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE Trigger [dbo].[trig_d_ORF_Database_List] on [dbo].[T_ORF_Database_List]
For Delete
/****************************************************
**
**	Desc: 
**		Makes an entry in T_Event_Log for the deleted ORF database
**
**	Auth:	mem
**	Date:	08/10/2007
**    
*****************************************************/
AS
	-- Add entries to T_Event_Log for each job deleted from T_ORF_Database_List
	INSERT INTO T_Event_Log
		(
			Target_Type, Target_ID, 
			Target_State, Prev_Target_State, 
			Entered
		)
	SELECT	3 AS Target_Type, ODB_ID, 
			0 AS Target_State, ODB_State, 
			GETDATE()
	FROM deleted
	ORDER BY ODB_ID


GO
/****** Object:  Trigger [dbo].[trig_i_ORF_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Trigger trig_i_ORF_Database_List on T_ORF_Database_List
For Insert
/****************************************************
**
**	Desc: 
**		Makes an entry in T_Event_Log for the new ORF database
**
**	Auth:	mem
**	Date:	08/10/2007
**    
*****************************************************/
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 3, inserted.ODB_ID, inserted.ODB_State, 0, GetDate()
	FROM inserted


GO
/****** Object:  Trigger [dbo].[trig_u_ORF_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Trigger trig_u_ORF_Database_List on T_ORF_Database_List
For Update
/****************************************************
**
**	Desc: 
**		Makes an entry in T_Event_Log for the updated ORF database
**
**	Auth:	mem
**	Date:	08/10/2007
**    
*****************************************************/
AS
	If @@RowCount = 0
		Return

	if update(ODB_State)
		INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
		SELECT 3, inserted.ODB_ID, inserted.ODB_State, deleted.ODB_State, GetDate()
		FROM deleted INNER JOIN inserted ON deleted.ODB_ID = inserted.ODB_ID


GO
ALTER TABLE [dbo].[T_ORF_Database_List]  WITH NOCHECK ADD  CONSTRAINT [FK_T_ORF_Database_List_T_MT_Database_State_Name] FOREIGN KEY([ODB_State])
REFERENCES [T_MT_Database_State_Name] ([ID])
GO
ALTER TABLE [dbo].[T_ORF_Database_List] CHECK CONSTRAINT [FK_T_ORF_Database_List_T_MT_Database_State_Name]
GO
ALTER TABLE [dbo].[T_ORF_Database_List] ADD  CONSTRAINT [DF_T_ORF_Database_List_ODB_Created]  DEFAULT (getdate()) FOR [ODB_Created]
GO
ALTER TABLE [dbo].[T_ORF_Database_List] ADD  CONSTRAINT [DF_T_ORF_Database_List_ODB_DB_Schema_Version]  DEFAULT (1) FOR [ODB_DB_Schema_Version]
GO
