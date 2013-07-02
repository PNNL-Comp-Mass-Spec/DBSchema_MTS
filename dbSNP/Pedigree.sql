/****** Object:  Table [dbo].[Pedigree] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Pedigree](
	[ped_id] [numeric](18, 0) NOT NULL,
	[curator] [varchar](12) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[curator_ped_id] [varchar](12) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[create_time] [smalldatetime] NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_curator_ped_id] ******/
CREATE NONCLUSTERED INDEX [i_curator_ped_id] ON [dbo].[Pedigree] 
(
	[curator] ASC,
	[curator_ped_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
