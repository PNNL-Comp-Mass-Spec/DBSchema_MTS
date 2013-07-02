/****** Object:  Table [dbo].[SubSNPLinkout] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubSNPLinkout](
	[subsnp_id] [int] NOT NULL,
	[url_val] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[updated_time] [smalldatetime] NULL,
	[link_type] [varchar](3) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]

GO
