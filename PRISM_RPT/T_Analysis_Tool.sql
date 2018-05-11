/****** Object:  Table [dbo].[T_Analysis_Tool] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Tool](
	[Tool_ID] [int] NOT NULL,
	[Tool_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Param_File_Storage_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Tool_Active] [tinyint] NOT NULL,
	[Cache_Update_State] [int] NOT NULL,
	[Cache_Update_Start] [datetime] NULL,
	[Cache_Update_Finish] [datetime] NULL,
	[Cache_Updated_By] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [T_Analysis_Tool_PK] PRIMARY KEY CLUSTERED 
(
	[Tool_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Analysis_Tool] ADD  CONSTRAINT [DF_T_Analysis_Tool_Tool_Active]  DEFAULT ((1)) FOR [Tool_Active]
GO
ALTER TABLE [dbo].[T_Analysis_Tool] ADD  CONSTRAINT [DF_T_Analysis_Tool_Cache_Update_State]  DEFAULT ((1)) FOR [Cache_Update_State]
GO
ALTER TABLE [dbo].[T_Analysis_Tool]  WITH CHECK ADD  CONSTRAINT [FK_T_Analysis_Tool_T_Analysis_Task_Cache_Update_State_Name] FOREIGN KEY([Cache_Update_State])
REFERENCES [dbo].[T_Analysis_Task_Cache_Update_State_Name] ([Cache_Update_State])
GO
ALTER TABLE [dbo].[T_Analysis_Tool] CHECK CONSTRAINT [FK_T_Analysis_Tool_T_Analysis_Task_Cache_Update_State_Name]
GO
/****** Object:  Trigger [dbo].[trig_u_T_Analysis_Tool] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[trig_u_T_Analysis_Tool] ON [dbo].[T_Analysis_Tool] 
FOR UPDATE
AS
/****************************************************
**
**	Desc: 
**		Updates the Cache_Updated_By field if Cache_Update_Start or Cache_Update_Finish is changed
**		Note that the SYSTEM_USER and suser_sname() functions are equivalent, with
**		 both returning the username in the form PNL\D3L243 if logged in using 
**		 integrated authentication or returning the Sql Server login name if
**		 logged in with a Sql Server login
**
**	Auth:	mem
**	Date:	12/21/2007
**    
*****************************************************/
	
	If @@RowCount = 0
		Return

	If Update(Cache_Update_Start) OR
	   Update(Cache_Update_Finish)
	Begin
		UPDATE T_Analysis_Tool
		SET Cache_Updated_By = SYSTEM_USER
		FROM T_Analysis_Tool INNER JOIN 
			 inserted ON T_Analysis_Tool.Tool_ID = inserted.Tool_ID

	End


GO
ALTER TABLE [dbo].[T_Analysis_Tool] ENABLE TRIGGER [trig_u_T_Analysis_Tool]
GO
