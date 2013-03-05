/****** Object:  Table [dbo].[T_DMS_Filter_Set_Overview_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Filter_Set_Overview_Cached](
	[Filter_Set_ID] [int] NOT NULL,
	[Filter_Type_ID] [int] NOT NULL,
	[Filter_Type_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Filter_Set_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Filter_Set_Description] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Last_Affected] [datetime] NULL,
 CONSTRAINT [PK_T_DMS_Filter_Set_Overview_Cached] PRIMARY KEY CLUSTERED 
(
	[Filter_Set_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_DMS_Filter_Set_Overview_Cached_FilterTypeID] ******/
CREATE NONCLUSTERED INDEX [IX_T_DMS_Filter_Set_Overview_Cached_FilterTypeID] ON [dbo].[T_DMS_Filter_Set_Overview_Cached] 
(
	[Filter_Type_ID] ASC
)
INCLUDE ( [Filter_Set_ID]) WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_DMS_Filter_Set_Overview_Cached] ADD  CONSTRAINT [DF_T_DMS_Filter_Set_Overview_Cached_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
