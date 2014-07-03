/****** Object:  Table [dbo].[T_Peak_Matching_Task] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peak_Matching_Task](
	[Task_ID] [int] IDENTITY(1,1) NOT NULL,
	[Job] [int] NOT NULL,
	[Confirmed_Only] [tinyint] NOT NULL,
	[Mod_List] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Minimum_High_Normalized_Score] [real] NOT NULL,
	[Minimum_High_Discriminant_Score] [real] NOT NULL,
	[Minimum_Peptide_Prophet_Probability] [real] NOT NULL,
	[Minimum_PMT_Quality_Score] [real] NOT NULL,
	[Experiment_Filter] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Experiment_Exclusion_Filter] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Limit_To_PMTs_From_Dataset] [tinyint] NOT NULL,
	[Internal_Std_Explicit] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[NET_Value_Type] [tinyint] NOT NULL,
	[Ini_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Output_Folder_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Processing_State] [tinyint] NOT NULL,
	[Priority] [tinyint] NOT NULL,
	[Processing_Error_Code] [int] NOT NULL,
	[Processing_Warning_Code] [int] NOT NULL,
	[PM_Created] [datetime] NULL,
	[PM_Start] [datetime] NULL,
	[PM_Finish] [datetime] NULL,
	[PM_AssignedProcessorName] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MD_ID] [int] NULL,
	[Entered_By] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Peak_Matching_Task] PRIMARY KEY CLUSTERED 
(
	[Task_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT DELETE ON [dbo].[T_Peak_Matching_Task] TO [DMS_SP_User] AS [dbo]
GO
GRANT INSERT ON [dbo].[T_Peak_Matching_Task] TO [DMS_SP_User] AS [dbo]
GO
GRANT SELECT ON [dbo].[T_Peak_Matching_Task] TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Peak_Matching_Task] TO [DMS_SP_User] AS [dbo]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Confirmed_Only]  DEFAULT ((0)) FOR [Confirmed_Only]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Mod_List]  DEFAULT ('') FOR [Mod_List]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Minimum_High_Normalized_Score]  DEFAULT ((1.0)) FOR [Minimum_High_Normalized_Score]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Minimum_High_Discriminant_Score]  DEFAULT ((0)) FOR [Minimum_High_Discriminant_Score]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Minimum_Peptide_Prophet_Probability]  DEFAULT ((0)) FOR [Minimum_Peptide_Prophet_Probability]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Minimum_PMT_Quality_Score]  DEFAULT ((0)) FOR [Minimum_PMT_Quality_Score]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Experiment_Filter]  DEFAULT ('') FOR [Experiment_Filter]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Experiment_Exclusion_Filter]  DEFAULT ('') FOR [Experiment_Exclusion_Filter]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Only_Use_PMTs_From_Dataset]  DEFAULT ((0)) FOR [Limit_To_PMTs_From_Dataset]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Internal_Std_Explicit]  DEFAULT ('') FOR [Internal_Std_Explicit]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_NET_Value_Type]  DEFAULT ((0)) FOR [NET_Value_Type]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Ini_File_Name]  DEFAULT ('') FOR [Ini_File_Name]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Output_Folder_Name]  DEFAULT ('') FOR [Output_Folder_Name]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Processing_State]  DEFAULT ((1)) FOR [Processing_State]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Priority]  DEFAULT ((5)) FOR [Priority]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Processing_Error_Code]  DEFAULT ((0)) FOR [Processing_Error_Code]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Processing_Warning_Code]  DEFAULT ((0)) FOR [Processing_Warning_Code]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Creation_Date]  DEFAULT (getdate()) FOR [PM_Created]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] ADD  CONSTRAINT [DF_T_Peak_Matching_Task_Entered_By]  DEFAULT (suser_sname()) FOR [Entered_By]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task]  WITH CHECK ADD  CONSTRAINT [FK_T_Peak_Matching_Task_T_FTICR_Analysis_Description] FOREIGN KEY([Job])
REFERENCES [dbo].[T_FTICR_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] CHECK CONSTRAINT [FK_T_Peak_Matching_Task_T_FTICR_Analysis_Description]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task]  WITH CHECK ADD  CONSTRAINT [FK_T_Peak_Matching_Task_T_Match_Making_Description] FOREIGN KEY([MD_ID])
REFERENCES [dbo].[T_Match_Making_Description] ([MD_ID])
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] CHECK CONSTRAINT [FK_T_Peak_Matching_Task_T_Match_Making_Description]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task]  WITH CHECK ADD  CONSTRAINT [FK_T_Peak_Matching_Task_T_Peak_Matching_NET_Value_Type_Name] FOREIGN KEY([NET_Value_Type])
REFERENCES [dbo].[T_Peak_Matching_NET_Value_Type_Name] ([NET_Value_Type])
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] CHECK CONSTRAINT [FK_T_Peak_Matching_Task_T_Peak_Matching_NET_Value_Type_Name]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task]  WITH CHECK ADD  CONSTRAINT [FK_T_Peak_Matching_Task_T_Peak_Matching_Task_State_Name] FOREIGN KEY([Processing_State])
REFERENCES [dbo].[T_Peak_Matching_Task_State_Name] ([Processing_State])
ON UPDATE CASCADE
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] CHECK CONSTRAINT [FK_T_Peak_Matching_Task_T_Peak_Matching_Task_State_Name]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task]  WITH CHECK ADD  CONSTRAINT [CK_T_Peak_Matching_Task_IniFileName_CRLF] CHECK  ((charindex(char((10)),isnull([Ini_File_Name],''))=(0) AND charindex(char((13)),isnull([Ini_File_Name],''))=(0)))
GO
ALTER TABLE [dbo].[T_Peak_Matching_Task] CHECK CONSTRAINT [CK_T_Peak_Matching_Task_IniFileName_CRLF]
GO
/****** Object:  Trigger [dbo].[trig_i_T_PeakMatchingTask] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_i_T_PeakMatchingTask] on [dbo].[T_Peak_Matching_Task]
For Insert
AS
	If @@RowCount = 0
		Return

	INSERT INTO T_Event_Log	(Target_Type, Target_ID, Target_State, Prev_Target_State, Entered)
	SELECT 3, inserted.Task_ID, inserted.Processing_State, 0, GetDate()
	FROM inserted

GO
/****** Object:  Trigger [dbo].[trig_u_T_Peak_Matching_Task] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TRIGGER [trig_u_T_Peak_Matching_Task] ON dbo.T_Peak_Matching_Task 
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
**		Date: 08/31/2006
**    
*****************************************************/
	
	If @@RowCount = 0
		Return

	Declare @UpdateEnteredBy tinyint
	Set @UpdateEnteredBy = 0

	-- Note: Column Processing_State is checked below
	If	Update(Job) OR
		Update(Confirmed_Only) OR
		Update(Mod_List) OR
	    Update(Minimum_High_Normalized_Score) OR
	    Update(Minimum_High_Discriminant_Score) OR
	    Update(Minimum_PMT_Quality_Score) OR
		Update(Experiment_Filter) OR
	    Update(Experiment_Exclusion_Filter) OR
		Update(Limit_To_PMTs_From_Dataset) OR
	    Update(Internal_Std_Explicit) OR
		Update(NET_Value_Type) OR
		Update(Ini_File_Name) OR
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
			SELECT 3, inserted.Task_ID, inserted.Processing_State, deleted.Processing_State, GetDate()
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

		UPDATE T_Peak_Matching_Task
		SET Entered_By = CASE WHEN LookupQ.MatchLoc > 0 THEN Left(T_Peak_Matching_Task.Entered_By, LookupQ.MatchLoc-1) + @SepChar + @UserInfo + ')'
						 WHEN T_Peak_Matching_Task.Entered_By IS NULL Then SYSTEM_USER
						 ELSE IsNull(T_Peak_Matching_Task.Entered_By, '??') + @SepChar + @UserInfo + ')'
						 END
		FROM T_Peak_Matching_Task INNER JOIN 
				(SELECT Task_ID, CharIndex(@SepChar, IsNull(Entered_By, '')) AS MatchLoc
				 FROM inserted 
				) LookupQ ON T_Peak_Matching_Task.Task_ID = LookupQ.Task_ID

	End

GO
