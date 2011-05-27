/****** Object:  Table [dbo].[T_DMS_Enzymes_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Enzymes_Cached](
	[Enzyme_ID] [int] NOT NULL,
	[Enzyme_Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Description] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Protein_Collection_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Last_Affected] [datetime] NULL,
 CONSTRAINT [PK_T_DMS_Enzymes_Cached] PRIMARY KEY CLUSTERED 
(
	[Enzyme_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_DMS_Enzymes_Cached] ADD  CONSTRAINT [DF_T_DMS_Enzymes_Cached_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
