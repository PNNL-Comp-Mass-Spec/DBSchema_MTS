/****** Object:  Table [dbo].[T_MT_Collection] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MT_Collection](
	[MT_Collection_ID] [int] IDENTITY(1,1) NOT NULL,
	[Discriminant_Score_Minimum] [real] NOT NULL,
	[Peptide_Prophet_Minimum] [real] NOT NULL,
	[PMT_Quality_Score_Minimum] [real] NOT NULL,
	[Job_Count] [int] NULL,
	[AMT_Count] [int] NULL,
	[Entered] [datetime] NOT NULL,
 CONSTRAINT [PK_T_MT_Collection] PRIMARY KEY CLUSTERED 
(
	[MT_Collection_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_MT_Collection] ADD  CONSTRAINT [DF_T_MT_Collection_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
