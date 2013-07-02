/****** Object:  Table [dbo].[SNPHWProb] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPHWProb](
	[snp_id] [int] NOT NULL,
	[df] [tinyint] NULL,
	[chisq] [real] NULL,
	[hwp] [real] NULL,
	[ind_cnt] [smallint] NULL,
	[last_updated_time] [smalldatetime] NULL
) ON [PRIMARY]

GO
