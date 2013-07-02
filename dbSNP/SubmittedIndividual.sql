/****** Object:  Table [dbo].[SubmittedIndividual] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SubmittedIndividual](
	[submitted_ind_id] [int] NOT NULL,
	[pop_id] [int] NOT NULL,
	[loc_ind_id_upp] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ind_id] [int] NULL,
	[create_time] [smalldatetime] NOT NULL,
	[last_updated_time] [smalldatetime] NULL,
	[tax_id] [int] NOT NULL,
	[loc_ind_alias] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[loc_ind_id] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[loc_ind_grp] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ploidy] [tinyint] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_ind] ******/
CREATE NONCLUSTERED INDEX [i_ind] ON [dbo].[SubmittedIndividual] 
(
	[ind_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [i_submitted_ind_id] ******/
CREATE NONCLUSTERED INDEX [i_submitted_ind_id] ON [dbo].[SubmittedIndividual] 
(
	[submitted_ind_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
