/****** Object:  Table [dbo].[IndivSourceCode] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IndivSourceCode](
	[code] [int] NOT NULL,
	[name] [varchar](22) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[descrip] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[create_time] [smalldatetime] NOT NULL,
	[src_type] [varchar](10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[display_order] [tinyint] NULL
) ON [PRIMARY]

GO
