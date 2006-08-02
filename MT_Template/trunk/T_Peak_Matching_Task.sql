if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peak_Matching_Task]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peak_Matching_Task]
GO

CREATE TABLE [T_Peak_Matching_Task] (
	[Task_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[Job] [int] NOT NULL ,
	[Confirmed_Only] [tinyint] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Confirmed_Only] DEFAULT (0),
	[Mod_List] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Mod_List] DEFAULT (''),
	[Minimum_High_Normalized_Score] [real] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Minimum_High_Normalized_Score] DEFAULT (1.0),
	[Minimum_High_Discriminant_Score] [real] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Minimum_High_Discriminant_Score] DEFAULT (0),
	[Minimum_PMT_Quality_Score] [real] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Minimum_PMT_Quality_Score] DEFAULT (0),
	[Experiment_Filter] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Experiment_Filter] DEFAULT (''),
	[Experiment_Exclusion_Filter] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Experiment_Exclusion_Filter] DEFAULT (''),
	[Limit_To_PMTs_From_Dataset] [tinyint] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Only_Use_PMTs_From_Dataset] DEFAULT (0),
	[Internal_Std_Explicit] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Internal_Std_Explicit] DEFAULT (''),
	[NET_Value_Type] [tinyint] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_NET_Value_Type] DEFAULT (0),
	[Ini_File_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Ini_File_Name] DEFAULT (''),
	[Output_Folder_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Output_Folder_Name] DEFAULT (''),
	[Processing_State] [tinyint] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Processing_State] DEFAULT (1),
	[Priority] [tinyint] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Priority] DEFAULT (5),
	[Processing_Error_Code] [int] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Processing_Error_Code] DEFAULT (0),
	[Processing_Warning_Code] [int] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Task_Processing_Warning_Code] DEFAULT (0),
	[PM_Created] [datetime] NULL CONSTRAINT [DF_T_Peak_Matching_Task_Creation_Date] DEFAULT (getdate()),
	[PM_Start] [datetime] NULL ,
	[PM_Finish] [datetime] NULL ,
	[PM_AssignedProcessorName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[MD_ID] [int] NULL ,
	CONSTRAINT [PK_T_Peak_Matching_Task] PRIMARY KEY  CLUSTERED 
	(
		[Task_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Peak_Matching_Task_T_FTICR_Analysis_Description] FOREIGN KEY 
	(
		[Job]
	) REFERENCES [T_FTICR_Analysis_Description] (
		[Job]
	),
	CONSTRAINT [FK_T_Peak_Matching_Task_T_Match_Making_Description] FOREIGN KEY 
	(
		[MD_ID]
	) REFERENCES [T_Match_Making_Description] (
		[MD_ID]
	),
	CONSTRAINT [FK_T_Peak_Matching_Task_T_Peak_Matching_NET_Value_Type_Name] FOREIGN KEY 
	(
		[NET_Value_Type]
	) REFERENCES [T_Peak_Matching_NET_Value_Type_Name] (
		[NET_Value_Type]
	),
	CONSTRAINT [FK_T_Peak_Matching_Task_T_Peak_Matching_Task_State_Name] FOREIGN KEY 
	(
		[Processing_State]
	) REFERENCES [T_Peak_Matching_Task_State_Name] (
		[Processing_State]
	) ON UPDATE CASCADE ,
	CONSTRAINT [CK_T_Peak_Matching_Task_IniFileName_CRLF] CHECK (charindex(char(10),isnull([Ini_File_Name],'')) = 0 and charindex(char(13),isnull([Ini_File_Name],'')) = 0)
) ON [PRIMARY]
GO

GRANT  SELECT ,  UPDATE ,  INSERT ,  DELETE  ON [dbo].[T_Peak_Matching_Task]  TO [DMS_SP_User]
GO


