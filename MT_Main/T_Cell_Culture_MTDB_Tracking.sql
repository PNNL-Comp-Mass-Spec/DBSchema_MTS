/****** Object:  Table [dbo].[T_Cell_Culture_MTDB_Tracking] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Cell_Culture_MTDB_Tracking](
	[CellCulture] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MTDatabase] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Experiments] [int] NULL,
	[Datasets] [int] NULL,
	[Jobs] [int] NULL,
	[MTDatabaseID] [int] NULL,
	[CCID] [int] NULL
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Cell_Culture_MTDB_Tracking] ADD  CONSTRAINT [DF_T_Cell_Culture_MTDB_Tracking_Experiments]  DEFAULT (0) FOR [Experiments]
GO
ALTER TABLE [dbo].[T_Cell_Culture_MTDB_Tracking] ADD  CONSTRAINT [DF_T_Cell_Culture_MTDB_Tracking_Datasets]  DEFAULT (0) FOR [Datasets]
GO
ALTER TABLE [dbo].[T_Cell_Culture_MTDB_Tracking] ADD  CONSTRAINT [DF_T_Cell_Culture_MTDB_Tracking_Jobs]  DEFAULT (0) FOR [Jobs]
GO
