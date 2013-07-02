/****** Object:  Table [dbo].[SubSNPNoVariSeq] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubSNPNoVariSeq](
	[subsnp_id] [int] NOT NULL,
	[line_num] [tinyint] NOT NULL,
	[line] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]

GO
