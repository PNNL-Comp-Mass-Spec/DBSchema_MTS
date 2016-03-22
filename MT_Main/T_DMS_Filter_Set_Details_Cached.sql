/****** Object:  Table [dbo].[T_DMS_Filter_Set_Details_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Filter_Set_Details_Cached](
	[Filter_Set_Criteria_ID] [int] NOT NULL,
	[Filter_Set_ID] [int] NOT NULL,
	[Filter_Criteria_Group_ID] [int] NOT NULL,
	[Criterion_ID] [int] NOT NULL,
	[Criterion_Comparison] [char](2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Criterion_Value] [float] NOT NULL,
	[Last_Affected] [datetime] NULL,
 CONSTRAINT [PK_T_DMS_Filter_Set_Details_Cached] PRIMARY KEY NONCLUSTERED 
(
	[Filter_Set_Criteria_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_DMS_Filter_Set_Details_Cached_FilterSetID_GroupID_CriterionID] ******/
CREATE CLUSTERED INDEX [IX_T_DMS_Filter_Set_Details_Cached_FilterSetID_GroupID_CriterionID] ON [dbo].[T_DMS_Filter_Set_Details_Cached]
(
	[Filter_Set_ID] ASC,
	[Filter_Criteria_Group_ID] ASC,
	[Criterion_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [IX_T_DMS_Filter_Set_Details_Cached_CriteriaGroupID_CriterionID] ******/
CREATE NONCLUSTERED INDEX [IX_T_DMS_Filter_Set_Details_Cached_CriteriaGroupID_CriterionID] ON [dbo].[T_DMS_Filter_Set_Details_Cached]
(
	[Filter_Criteria_Group_ID] ASC,
	[Criterion_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_DMS_Filter_Set_Details_Cached] ADD  CONSTRAINT [DF_T_DMS_Filter_Set_Details_Cached_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
ALTER TABLE [dbo].[T_DMS_Filter_Set_Details_Cached]  WITH CHECK ADD  CONSTRAINT [FK_T_DMS_Filter_Set_Details_Cached_T_DMS_Filter_Set_Criteria_Names_Cached] FOREIGN KEY([Criterion_ID])
REFERENCES [dbo].[T_DMS_Filter_Set_Criteria_Names_Cached] ([Criterion_ID])
GO
ALTER TABLE [dbo].[T_DMS_Filter_Set_Details_Cached] CHECK CONSTRAINT [FK_T_DMS_Filter_Set_Details_Cached_T_DMS_Filter_Set_Criteria_Names_Cached]
GO
