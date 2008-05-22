/****** Object:  Table [dbo].[T_MultiAlign_Task] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MultiAlign_Task](
	[Task_ID] [int] IDENTITY(1,1) NOT NULL,
	[Minimum_High_Normalized_Score] [real] NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Minimum_High_Normalized_Score]  DEFAULT ((1.0)),
	[Minimum_High_Discriminant_Score] [real] NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Minimum_High_Discriminant_Score]  DEFAULT ((0)),
	[Minimum_Peptide_Prophet_Probability] [real] NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Minimum_Peptide_Prophet_Probability]  DEFAULT ((0)),
	[Minimum_PMT_Quality_Score] [real] NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Minimum_PMT_Quality_Score]  DEFAULT ((0)),
	[Experiment_Filter] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Experiment_Filter]  DEFAULT (''),
	[Experiment_Exclusion_Filter] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Experiment_Exclusion_Filter]  DEFAULT (''),
	[Limit_To_PMTs_From_Dataset] [tinyint] NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Only_Use_PMTs_From_Dataset]  DEFAULT ((0)),
	[Internal_Std_Explicit] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Internal_Std_Explicit]  DEFAULT (''),
	[NET_Value_Type] [tinyint] NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_NET_Value_Type]  DEFAULT ((0)),
	[Param_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Param_File_Name]  DEFAULT (''),
	[Output_Folder_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Output_Folder_Name]  DEFAULT (''),
	[Processing_State] [tinyint] NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Processing_State]  DEFAULT ((1)),
	[Priority] [tinyint] NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Priority]  DEFAULT ((5)),
	[Processing_Error_Code] [int] NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Processing_Error_Code]  DEFAULT ((0)),
	[Processing_Warning_Code] [int] NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Processing_Warning_Code]  DEFAULT ((0)),
	[Job_Count] [int] NOT NULL CONSTRAINT [DF_T_MultiAlign_Task_Task_JobCount]  DEFAULT ((0)),
	[Task_Created] [datetime] NULL CONSTRAINT [DF_T_MultiAlign_Task_Creation_Date]  DEFAULT (getdate()),
	[Task_Start] [datetime] NULL,
	[Task_Finish] [datetime] NULL,
	[Task_AssignedProcessorName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Analysis_Results_ID] [int] NULL,
	[Entered_By] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [DF_T_MultiAlign_Task_Entered_By]  DEFAULT (suser_sname()),
 CONSTRAINT [PK_T_MultiAlign_Task] PRIMARY KEY CLUSTERED 
(
	[Task_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Trigger [dbo].[trig_i_T_MultiAlign_Task] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create Trigger trig_i_T_MultiAlign_Task on dbo.T_MultiAlign_Task
For Insert
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 4, inserted.Task_ID, inserted.Processing_State, 0, GetDate()
	FROM inserted

GO

/****** Object:  Trigger [dbo].[trig_u_T_MultiAlign_Task] ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create TRIGGER trig_u_T_MultiAlign_Task ON dbo.T_MultiAlign_Task 
FOR UPDATE
AS
/****************************************************
**
**	Desc: 
**		Updates the Entered_By field if any of the parameter fields are changed
**		Note that the SYSTEM_USER and suser_sname() functions are equivalent, with
**		 both returning the username in the form PNL\D3L243 if logged in using 
**		 integrated authentication or returning the Sql Server login name if
**		 logged in with a Sql Server login
**
**		Auth: mem
**		Date: 12/17/2007
**    
*****************************************************/
	
	If @@RowCount = 0
		Return

	Declare @UpdateEnteredBy tinyint
	Set @UpdateEnteredBy = 0

	-- Note: Column Processing_State is checked below
	If	Update(Minimum_High_Normalized_Score) OR
	    Update(Minimum_High_Discriminant_Score) OR
	    Update(Minimum_PMT_Quality_Score) OR
		Update(Experiment_Filter) OR
	    Update(Experiment_Exclusion_Filter) OR
		Update(Limit_To_PMTs_From_Dataset) OR
	    Update(Internal_Std_Explicit) OR
		Update(NET_Value_Type) OR
		Update(Param_File_Name) OR
		Update(Processing_State)
	Begin
		If Update(Processing_State)
		Begin
			Declare @MatchCount int
	
			Set @MatchCount = 0
			SELECT @MatchCount = Count(*)
			FROM inserted
			WHERE Processing_State = 1
	
			If @MatchCount > 0
				Set @UpdateEnteredBy = 1

			INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
			SELECT 4, inserted.Task_ID, inserted.Processing_State, deleted.Processing_State, GetDate()
			FROM deleted INNER JOIN inserted ON deleted.Task_ID = inserted.Task_ID

		End
		Else
		Begin
			Set @UpdateEnteredBy = 1
		End
	End

	If @UpdateEnteredBy = 1
	Begin
		Declare @SepChar varchar(2)
		set @SepChar = ' ('

		-- Note that dbo.udfTimeStampText returns a timestamp 
		-- in the form: 2006-09-01 09:05:03

		Declare @UserInfo varchar(128)
		Set @UserInfo = dbo.udfTimeStampText(GetDate()) + '; ' + LEFT(SYSTEM_USER,75)
		Set @UserInfo = IsNull(@UserInfo, '')

		UPDATE T_MultiAlign_Task
		SET Entered_By = CASE WHEN LookupQ.MatchLoc > 0 THEN Left(T_MultiAlign_Task.Entered_By, LookupQ.MatchLoc-1) + @SepChar + @UserInfo + ')'
						 WHEN T_MultiAlign_Task.Entered_By IS NULL Then SYSTEM_USER
						 ELSE IsNull(T_MultiAlign_Task.Entered_By, '??') + @SepChar + @UserInfo + ')'
						 END
		FROM T_MultiAlign_Task INNER JOIN 
				(SELECT Task_ID, CharIndex(@SepChar, IsNull(Entered_By, '')) AS MatchLoc
				 FROM inserted 
				) LookupQ ON T_MultiAlign_Task.Task_ID = LookupQ.Task_ID

	End

GO
ALTER TABLE [dbo].[T_MultiAlign_Task]  WITH CHECK ADD  CONSTRAINT [FK_T_MultiAlign_Task_T_Peak_Matching_NET_Value_Type_Name] FOREIGN KEY([NET_Value_Type])
REFERENCES [T_Peak_Matching_NET_Value_Type_Name] ([NET_Value_Type])
GO
ALTER TABLE [dbo].[T_MultiAlign_Task] CHECK CONSTRAINT [FK_T_MultiAlign_Task_T_Peak_Matching_NET_Value_Type_Name]
GO
ALTER TABLE [dbo].[T_MultiAlign_Task]  WITH CHECK ADD  CONSTRAINT [FK_T_MultiAlign_Task_T_Peak_Matching_Task_State_Name] FOREIGN KEY([Processing_State])
REFERENCES [T_Peak_Matching_Task_State_Name] ([Processing_State])
ON UPDATE CASCADE
GO
ALTER TABLE [dbo].[T_MultiAlign_Task] CHECK CONSTRAINT [FK_T_MultiAlign_Task_T_Peak_Matching_Task_State_Name]
GO
ALTER TABLE [dbo].[T_MultiAlign_Task]  WITH CHECK ADD  CONSTRAINT [CK_T_MultiAlign_Task_ParamFileName_CRLF] CHECK  ((charindex(char((10)),isnull([Param_File_Name],''))=(0) AND charindex(char((13)),isnull([Param_File_Name],''))=(0)))
GO
ALTER TABLE [dbo].[T_MultiAlign_Task] CHECK CONSTRAINT [CK_T_MultiAlign_Task_ParamFileName_CRLF]
GO
