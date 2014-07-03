/****** Object:  Table [dbo].[T_Process_Step_Control] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Process_Step_Control](
	[Processing_Step_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Execution_State] [int] NOT NULL,
	[Last_Query_Date] [datetime] NULL,
	[Last_Query_Description] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Last_Query_Update_Count] [int] NOT NULL,
	[Pause_Location] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Last_Affected] [datetime] NULL,
	[Entered_By] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Process_Step_Control] PRIMARY KEY CLUSTERED 
(
	[Processing_Step_Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT UPDATE ON [dbo].[T_Process_Step_Control] ([Execution_State]) TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Process_Step_Control] ([Last_Query_Date]) TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Process_Step_Control] ([Last_Query_Description]) TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Process_Step_Control] ([Last_Query_Update_Count]) TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Process_Step_Control] ([Pause_Location]) TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Process_Step_Control] ([Last_Affected]) TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Process_Step_Control] ([Entered_By]) TO [DMS_SP_User] AS [dbo]
GO
ALTER TABLE [dbo].[T_Process_Step_Control] ADD  CONSTRAINT [DF_T_Process_Step_Control_Execution_State]  DEFAULT (0) FOR [Execution_State]
GO
ALTER TABLE [dbo].[T_Process_Step_Control] ADD  CONSTRAINT [DF_T_Process_Step_Control_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
ALTER TABLE [dbo].[T_Process_Step_Control] ADD  CONSTRAINT [DF_T_Process_Step_Control_Entered_By]  DEFAULT (suser_sname()) FOR [Entered_By]
GO
ALTER TABLE [dbo].[T_Process_Step_Control]  WITH CHECK ADD  CONSTRAINT [FK_T_Process_Step_Control_T_Process_Step_Control_States] FOREIGN KEY([Execution_State])
REFERENCES [dbo].[T_Process_Step_Control_States] ([Execution_State])
GO
ALTER TABLE [dbo].[T_Process_Step_Control] CHECK CONSTRAINT [FK_T_Process_Step_Control_T_Process_Step_Control_States]
GO
/****** Object:  Trigger [dbo].[trig_u_T_Process_Step_Control] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[trig_u_T_Process_Step_Control] ON [dbo].[T_Process_Step_Control] 
FOR UPDATE
AS
/****************************************************
**
**	Desc: 
**		Updates the Last_Affected and Entered_By fields 
**		if any of the other fields are changed
**		Note that the SYSTEM_USER and suser_sname() functions are equivalent, with
**		 both returning the username in the form PNL\D3L243 if logged in using 
**		 integrated authentication or returning the Sql Server login name if
**		 logged in with a Sql Server login
**
**		Auth: mem
**		Date: 08/30/2006
**    
*****************************************************/
	
	If @@RowCount = 0
		Return

	If Update([execution_state])
	Begin
		UPDATE T_Process_Step_Control
		SET Last_Affected = GetDate(),
			Entered_By = SYSTEM_USER
		FROM T_Process_Step_Control INNER JOIN 
			 inserted ON T_Process_Step_Control.Processing_Step_Name = inserted.Processing_Step_Name

	End


GO
