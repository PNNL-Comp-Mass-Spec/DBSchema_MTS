/****** Object:  Table [dbo].[T_PMT_Collection_Members] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_PMT_Collection_Members](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[PMT_Collection_ID] [int] NOT NULL,
	[Mass_Tag_ID] [int] NOT NULL,
	[Monoisotopic_Mass] [float] NULL,
	[NET] [real] NULL,
	[PMT_QS] [real] NULL,
	[Conformer_ID] [int] NULL,
	[Conformer_Charge] [smallint] NULL,
	[Conformer] [smallint] NULL,
	[Drift_Time_Avg] [real] NULL,
 CONSTRAINT [PK_T_PMT_Collection_Members] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_PMT_Collection_Members]  WITH CHECK ADD  CONSTRAINT [FK_T_PMT_Collection_Members_T_PMT_Collection] FOREIGN KEY([PMT_Collection_ID])
REFERENCES [T_PMT_Collection] ([PMT_Collection_ID])
GO
ALTER TABLE [dbo].[T_PMT_Collection_Members] CHECK CONSTRAINT [FK_T_PMT_Collection_Members_T_PMT_Collection]
GO
