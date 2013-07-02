/****** Object:  Table [dbo].[dn_IND_batchCount] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dn_IND_batchCount](
	[batch_id] [int] NOT NULL,
	[pop_id] [int] NOT NULL,
	[ss_cnt] [int] NOT NULL,
	[rs_cnt] [int] NOT NULL,
	[ind_cnt] [int] NOT NULL,
	[create_time] [datetime] NOT NULL
) ON [PRIMARY]

GO
