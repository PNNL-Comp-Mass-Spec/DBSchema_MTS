/****** Object:  Table [dbo].[T_MT_Collection_Members] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MT_Collection_Members](
	[MT_Collection_ID] [int] NOT NULL,
	[Mass_Tag_ID] [int] NOT NULL,
	[Peptide_Obs_Count] [int] NULL,
	[Peptide_Obs_Count_Passing_Filter] [int] NULL,
	[High_Normalized_Score] [real] NULL,
	[High_Discriminant_Score] [real] NULL,
	[High_Peptide_Prophet_Probability] [real] NULL,
	[PMT_Quality_Score] [real] NULL,
	[Cleavage_State_Max] [tinyint] NULL,
	[NET_Avg] [real] NULL,
	[NET_Count] [int] NULL,
	[NET_StDev] [real] NULL,
 CONSTRAINT [PK_T_MT_Collection_Members] PRIMARY KEY CLUSTERED 
(
	[MT_Collection_ID] ASC,
	[Mass_Tag_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_MT_Collection_Members]  WITH CHECK ADD  CONSTRAINT [FK_T_MT_Collection_Members_T_MT_Collection] FOREIGN KEY([MT_Collection_ID])
REFERENCES [dbo].[T_MT_Collection] ([MT_Collection_ID])
GO
ALTER TABLE [dbo].[T_MT_Collection_Members] CHECK CONSTRAINT [FK_T_MT_Collection_Members_T_MT_Collection]
GO
