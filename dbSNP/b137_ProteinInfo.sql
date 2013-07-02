/****** Object:  Table [dbo].[b137_ProteinInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[b137_ProteinInfo](
	[gi] [int] NOT NULL,
	[acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[version] [smallint] NOT NULL,
	[prot_gi] [int] NOT NULL,
	[prot_acc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[prot_ver] [smallint] NOT NULL,
	[status] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[create_dt] [smalldatetime] NULL,
	[update_dt] [smalldatetime] NULL
) ON [PRIMARY]

GO

/****** Object:  Index [i_gi] ******/
CREATE CLUSTERED INDEX [i_gi] ON [dbo].[b137_ProteinInfo] 
(
	[gi] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
