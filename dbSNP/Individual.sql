/****** Object:  Table [dbo].[Individual] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Individual](
	[ind_id] [int] NOT NULL,
	[descrip] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[create_time] [smalldatetime] NOT NULL,
	[tax_id] [int] NULL,
	[ind_grp] [tinyint] NULL
) ON [PRIMARY]

GO
