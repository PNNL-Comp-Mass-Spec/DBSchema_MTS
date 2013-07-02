/****** Object:  Table [dbo].[SubSNPMdFailLn] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubSNPMdFailLn](
	[subsnp_id] [int] NOT NULL,
	[line_num] [tinyint] NOT NULL,
	[line] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_subsnp_id] ******/
CREATE NONCLUSTERED INDEX [i_subsnp_id] ON [dbo].[SubSNPMdFailLn] 
(
	[subsnp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
