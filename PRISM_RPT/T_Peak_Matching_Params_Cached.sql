/****** Object:  Table [dbo].[T_Peak_Matching_Params_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peak_Matching_Params_Cached](
	[Job_ID] [int] NOT NULL,
	[Task_ID] [int] NOT NULL,
	[Task_Server] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Task_Database] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Priority] [tinyint] NOT NULL,
	[DMS_Job] [int] NOT NULL,
	[Minimum_High_Normalized_Score] [real] NOT NULL,
	[Minimum_High_Discriminant_Score] [real] NOT NULL,
	[Minimum_Peptide_Prophet_Probability] [real] NOT NULL,
	[Minimum_PMT_Quality_Score] [real] NOT NULL,
	[Experiment_Filter] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Experiment_Exclusion_Filter] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Limit_To_PMTs_From_Dataset] [tinyint] NOT NULL,
	[Internal_Std_Explicit] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[NET_Value_Type] [tinyint] NOT NULL,
	[ParamFileStoragePath] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ParamFileName] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[TransferFolderPath] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ResultsFolderName] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Cache_Date] [datetime] NULL,
 CONSTRAINT [PK_T_Peak_Matching_Params_Cached] PRIMARY KEY CLUSTERED 
(
	[Job_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Peak_Matching_Params_Cached] ADD  CONSTRAINT [DF_T_Peak_Matching_Params_Cached_Cache_Date]  DEFAULT (getdate()) FOR [Cache_Date]
GO
