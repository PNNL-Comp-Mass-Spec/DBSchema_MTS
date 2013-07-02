/****** Object:  Table [dbo].[SubSNPAcc_ins] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubSNPAcc_ins](
	[subsnp_id] [int] NOT NULL,
	[acc_type_ind] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[acc_part] [varchar](16) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[acc_ver] [int] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_acc_part_ind] ******/
CREATE NONCLUSTERED INDEX [i_acc_part_ind] ON [dbo].[SubSNPAcc_ins] 
(
	[acc_part] ASC,
	[acc_type_ind] ASC,
	[subsnp_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
