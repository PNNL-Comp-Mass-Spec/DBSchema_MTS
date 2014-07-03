/****** Object:  Table [dbo].[T_Log_Entries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Log_Entries](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[posted_by] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[posting_time] [datetime] NOT NULL,
	[type] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[message] [varchar](4096) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entered_By] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Log_Entries] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Log_Entries] ADD  CONSTRAINT [DF_T_Log_Entries_posting_time]  DEFAULT (getdate()) FOR [posting_time]
GO
ALTER TABLE [dbo].[T_Log_Entries] ADD  CONSTRAINT [DF_T_Log_Entries_Entered_By]  DEFAULT (suser_sname()) FOR [Entered_By]
GO
/****** Object:  Trigger [dbo].[trig_u_T_Log_Entries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER trig_u_T_Log_Entries ON dbo.T_Log_Entries 
FOR UPDATE
AS
/****************************************************
**
**	Desc: 
**		Updates the Entered_By field if any of the other fields are changed
**		Note that the SYSTEM_USER and suser_sname() functions are equivalent, with
**		 both returning the username in the form PNL\D3L243 if logged in using 
**		 integrated authentication or returning the Sql Server login name if
**		 logged in with a Sql Server login
**
**	Auth:	mem
**	Date:	08/17/2006
**			09/01/2006 mem - Updated to use dbo.udfTimeStampText
**    
*****************************************************/
	
	If @@RowCount = 0
		Return

	If Update(posted_by) OR
	   Update(posting_time) OR
	   Update(type) OR
	   Update(message)
	Begin
		Declare @SepChar varchar(2)
		set @SepChar = ' ('

		-- Note that dbo.udfTimeStampText returns a timestamp 
		-- in the form: 2006-09-01 09:05:03

		Declare @UserInfo varchar(128)
		Set @UserInfo = dbo.udfTimeStampText(GetDate()) + '; ' + LEFT(SYSTEM_USER,75)
		Set @UserInfo = IsNull(@UserInfo, '')

		UPDATE T_Log_Entries
		SET Entered_By = CASE WHEN LookupQ.MatchLoc > 0 THEN Left(T_Log_Entries.Entered_By, LookupQ.MatchLoc-1) + @SepChar + @UserInfo + ')'
						 WHEN T_Log_Entries.Entered_By IS NULL Then SYSTEM_USER
						 ELSE IsNull(T_Log_Entries.Entered_By, '??') + @SepChar + @UserInfo + ')'
						 END
		FROM T_Log_Entries INNER JOIN 
				(SELECT Entry_ID, CharIndex(@SepChar, IsNull(Entered_By, '')) AS MatchLoc
				 FROM inserted 
				) LookupQ ON T_Log_Entries.Entry_ID = LookupQ.Entry_ID

	End

GO
