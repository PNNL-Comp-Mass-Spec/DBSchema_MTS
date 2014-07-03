/****** Object:  Table [dbo].[T_PMT_Collection] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_PMT_Collection](
	[PMT_Collection_ID] [int] IDENTITY(1,1) NOT NULL,
	[Normalized_Score_Min] [real] NOT NULL,
	[Discriminant_Score_Min] [real] NOT NULL,
	[Peptide_Prophet_Min] [real] NOT NULL,
	[MSGF_SpecProb_Max] [real] NOT NULL,
	[PMT_QS_Min] [real] NOT NULL,
	[NET_Value_Type] [tinyint] NOT NULL,
	[Experiment_Filter] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Experiment_Exclusion_Filter] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Job_To_Filter_On_By_Dataset] [int] NOT NULL,
	[MassCorrectionID_Filter_List] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[AMT_Count] [int] NOT NULL,
	[AMT_Count_Distinct] [int] NOT NULL,
	[Conformer_Count] [int] NOT NULL,
	[Entered] [datetime] NOT NULL,
	[Last_Used] [datetime] NOT NULL,
	[Usage_Count] [int] NOT NULL,
 CONSTRAINT [PK_T_PMT_Collection] PRIMARY KEY CLUSTERED 
(
	[PMT_Collection_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_PMT_Collection] ADD  CONSTRAINT [DF_T_PMT_Collection_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
ALTER TABLE [dbo].[T_PMT_Collection] ADD  CONSTRAINT [DF_T_PMT_Collection_LastUsed]  DEFAULT (getdate()) FOR [Last_Used]
GO
ALTER TABLE [dbo].[T_PMT_Collection] ADD  CONSTRAINT [DF_T_PMT_Collection_Usage_Count]  DEFAULT ((1)) FOR [Usage_Count]
GO
