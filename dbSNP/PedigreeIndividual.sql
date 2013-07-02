/****** Object:  Table [dbo].[PedigreeIndividual] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PedigreeIndividual](
	[ped_id] [decimal](18, 0) NOT NULL,
	[ind_id] [int] NOT NULL,
	[ma_ind_id] [int] NULL,
	[pa_ind_id] [int] NULL,
	[sex] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[create_time] [smalldatetime] NOT NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_ind_ped] ******/
CREATE NONCLUSTERED INDEX [i_ind_ped] ON [dbo].[PedigreeIndividual] 
(
	[ind_id] ASC,
	[ped_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
