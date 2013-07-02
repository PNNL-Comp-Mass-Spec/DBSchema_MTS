/****** Object:  Table [dbo].[SNPVal] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPVal](
	[batch_id] [int] NOT NULL,
	[snp_id] [int] NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_rs] ******/
CREATE NONCLUSTERED INDEX [i_rs] ON [dbo].[SNPVal] 
(
	[snp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
