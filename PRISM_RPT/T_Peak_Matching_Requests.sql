/****** Object:  Table [dbo].[T_Peak_Matching_Requests] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peak_Matching_Requests](
	[Request] [int] IDENTITY(100,1) NOT NULL,
	[Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Tool] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Mass_Tag_Database] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Analysis_Jobs] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Parameter_file] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MinimumHighNormalizedScore] [varchar](12) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[MinimumHighDiscriminantScore] [varchar](12) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[MinimumPeptideProphetProbability] [varchar](12) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[MinimumPMTQualityScore] [varchar](12) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Limit_To_PMTs_From_Dataset] [varchar](12) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Comment] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Requester] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Created] [datetime] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Peak_Matching_Requests] ADD  CONSTRAINT [DF_T_Peak_Matching_Requests_Tool]  DEFAULT ('Viper') FOR [Tool]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Requests] ADD  CONSTRAINT [DF_T_Peak_Matching_Requests_MinimumHighNormalizedScore]  DEFAULT ((1)) FOR [MinimumHighNormalizedScore]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Requests] ADD  CONSTRAINT [DF_T_Peak_Matching_Requests_MinimumHighDiscriminantScore]  DEFAULT ((0)) FOR [MinimumHighDiscriminantScore]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Requests] ADD  CONSTRAINT [DF_T_Peak_Matching_Requests_MinimumPeptideProphetProbability]  DEFAULT ((0.5)) FOR [MinimumPeptideProphetProbability]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Requests] ADD  CONSTRAINT [DF_T_Peak_Matching_Requests_MinimumPMTQualityScore]  DEFAULT ((1)) FOR [MinimumPMTQualityScore]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Requests] ADD  CONSTRAINT [DF_T_Peak_Matching_Requests_Limit_To_PMTs_From_Dataset]  DEFAULT ((0)) FOR [Limit_To_PMTs_From_Dataset]
GO
ALTER TABLE [dbo].[T_Peak_Matching_Requests] ADD  CONSTRAINT [DF_T_Peak_Matching_Requests_Created]  DEFAULT (getdate()) FOR [Created]
GO
