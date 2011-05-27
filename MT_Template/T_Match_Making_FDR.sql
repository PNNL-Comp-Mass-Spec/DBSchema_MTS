/****** Object:  Table [dbo].[T_Match_Making_FDR] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Match_Making_FDR](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[MD_ID] [int] NOT NULL,
	[STAC_Cutoff] [real] NOT NULL,
	[Unique_AMTs] [int] NULL,
	[FDR] [real] NOT NULL,
	[Matches] [int] NOT NULL,
	[Errors] [real] NOT NULL,
	[UP_Filtered_Unique_AMTs] [int] NULL,
	[UP_Filtered_FDR] [real] NOT NULL,
	[UP_Filtered_Matches] [int] NOT NULL,
	[UP_Filtered_Errors] [real] NOT NULL,
 CONSTRAINT [PK_T_Match_Making_FDR] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Match_Making_FDR_MDID_STAC] ******/
CREATE NONCLUSTERED INDEX [IX_T_Match_Making_FDR_MDID_STAC] ON [dbo].[T_Match_Making_FDR] 
(
	[MD_ID] ASC,
	[STAC_Cutoff] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Match_Making_FDR]  WITH CHECK ADD  CONSTRAINT [FK_T_Match_Making_FDR_T_Match_Making_Description] FOREIGN KEY([MD_ID])
REFERENCES [T_Match_Making_Description] ([MD_ID])
GO
ALTER TABLE [dbo].[T_Match_Making_FDR] CHECK CONSTRAINT [FK_T_Match_Making_FDR_T_Match_Making_Description]
GO
