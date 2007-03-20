/****** Object:  Table [dbo].[T_Process_Step_Control] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Process_Step_Control](
	[Processing_Step_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[enabled] [int] NOT NULL CONSTRAINT [DF_T_Process_Step_Control_enabled]  DEFAULT (0),
	[Last_Affected] [datetime] NULL CONSTRAINT [DF_T_Process_Step_Control_Last_Affected]  DEFAULT (getdate()),
	[Entered_By] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [DF_T_Process_Step_Control_Entered_By]  DEFAULT (suser_sname()),
 CONSTRAINT [PK_T_Process_Step_Control] PRIMARY KEY CLUSTERED 
(
	[Processing_Step_Name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

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

	If Update([enabled])
	Begin
		UPDATE T_Process_Step_Control
		SET Last_Affected = GetDate(),
			Entered_By = SYSTEM_USER
		FROM T_Process_Step_Control INNER JOIN 
			 inserted ON T_Process_Step_Control.Processing_Step_Name = inserted.Processing_Step_Name

	End


GO
