/****** Object:  Table [dbo].[Synonym] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Synonym](
	[subsnp_id] [int] NOT NULL,
	[type] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]

GO
