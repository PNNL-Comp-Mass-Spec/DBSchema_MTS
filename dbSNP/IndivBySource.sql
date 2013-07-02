/****** Object:  Table [dbo].[IndivBySource] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IndivBySource](
	[ind_id] [int] NOT NULL,
	[src_id] [int] NOT NULL,
	[src_ind_id] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[create_time] [smalldatetime] NOT NULL,
	[src_ind_grp] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]

GO
