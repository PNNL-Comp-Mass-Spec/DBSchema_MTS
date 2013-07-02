/****** Object:  Table [dbo].[dn_batchCount] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dn_batchCount](
	[batch_id] [int] NOT NULL,
	[ss_cnt] [int] NOT NULL,
	[rs_cnt] [int] NOT NULL,
	[rs_validated_cnt] [int] NOT NULL,
	[create_time] [smalldatetime] NOT NULL,
	[pop_cnt] [int] NULL,
	[ind_cnt] [int] NULL
) ON [PRIMARY]

GO
