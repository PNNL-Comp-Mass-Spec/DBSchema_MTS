/****** Object:  Table [dbo].[T_Log_Entries] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Log_Entries](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[posted_by] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[posting_time] [datetime] NOT NULL,
	[type] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[message] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entered_By] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [DF_T_Log_Entries_Entered_By]  DEFAULT (suser_sname()),
 CONSTRAINT [PK_T_Log_Entries] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Trigger [dbo].[trig_u_T_Log_Entries] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER trig_u_T_Log_Entries ON T_Log_Entries 
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
**		Auth: mem
**		Date: 08/17/2006
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

		Declare @MonthCode varchar(2)
		Set @MonthCode = Convert(varchar(2), Month(GetDate()))
		If Len(@MonthCode) = 1
			Set @MonthCode = '0' + @MonthCode

		Declare @MinuteCode varchar(2)
		Set @MinuteCode = DATENAME(n, GetDate())
		If Len(@MinuteCode) = 1
			Set @MinuteCode = '0' + @MinuteCode

		Declare @DateTimeStamp varchar(20)
		Set @DateTimeStamp = DATENAME(yy, GetDate()) + '-' + @MonthCode + '-' + DATENAME(dd, GetDate()) + ' ' + DATENAME(hh, GetDate()) + ':' + @MinuteCode

		Declare @UserInfo varchar(128)
		Set @UserInfo = @DateTimeStamp + '; ' + LEFT(SYSTEM_USER,75)
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
