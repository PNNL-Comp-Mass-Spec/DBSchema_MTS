/****** Object:  Table [dbo].[T_DMS_Data_Package_Jobs_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Data_Package_Jobs_Cached](
	[Data_Package_ID] [int] NOT NULL,
	[Job] [int] NOT NULL,
	[Dataset] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Tool] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Package_Comment] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Item_Added] [datetime] NOT NULL,
	[Last_Affected] [smalldatetime] NOT NULL,
 CONSTRAINT [PK_T_DMS_Data_Package_Jobs_Cached] PRIMARY KEY CLUSTERED 
(
	[Data_Package_ID] ASC,
	[Job] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_DMS_Data_Package_Jobs_Cached] ******/
CREATE NONCLUSTERED INDEX [IX_T_DMS_Data_Package_Jobs_Cached] ON [dbo].[T_DMS_Data_Package_Jobs_Cached]
(
	[Job] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_DMS_Data_Package_Jobs_Cached] ADD  CONSTRAINT [DF_T_DMS_Data_Package_Jobs_Cached_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
