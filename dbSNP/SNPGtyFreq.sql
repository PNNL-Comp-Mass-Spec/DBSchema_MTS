/****** Object:  Table [dbo].[SNPGtyFreq] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SNPGtyFreq](
	[snp_id] [int] NOT NULL,
	[unigty_id] [int] NOT NULL,
	[ind_cnt] [float] NULL,
	[freq] [float] NULL,
	[last_updated_time] [datetime] NOT NULL
) ON [PRIMARY]

GO
