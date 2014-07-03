/****** Object:  Table [dbo].[T_DMS_Cached_Data_Status] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Cached_Data_Status](
	[Table_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Refresh_Count] [int] NOT NULL,
	[Insert_Count] [int] NOT NULL,
	[Update_Count] [int] NOT NULL,
	[Delete_Count] [int] NOT NULL,
	[Last_Refreshed] [datetime] NOT NULL,
	[Last_Refresh_Minimum_ID] [int] NULL,
	[Last_Full_Refresh] [datetime] NOT NULL,
 CONSTRAINT [PK_T_DMS_Cached_Data_Status] PRIMARY KEY CLUSTERED 
(
	[Table_Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_DMS_Cached_Data_Status] ADD  CONSTRAINT [DF_T_DMS_Cached_Data_Status_Refresh_Count]  DEFAULT ((0)) FOR [Refresh_Count]
GO
ALTER TABLE [dbo].[T_DMS_Cached_Data_Status] ADD  CONSTRAINT [DF_T_DMS_Cached_Data_Status_Insert_Count]  DEFAULT ((0)) FOR [Insert_Count]
GO
ALTER TABLE [dbo].[T_DMS_Cached_Data_Status] ADD  CONSTRAINT [DF_T_DMS_Cached_Data_Status_Update_Count]  DEFAULT ((0)) FOR [Update_Count]
GO
ALTER TABLE [dbo].[T_DMS_Cached_Data_Status] ADD  CONSTRAINT [DF_T_DMS_Cached_Data_Status_Delete_Count]  DEFAULT ((0)) FOR [Delete_Count]
GO
ALTER TABLE [dbo].[T_DMS_Cached_Data_Status] ADD  CONSTRAINT [DF_T_DMS_Cached_Data_Status_Last_Refreshed]  DEFAULT (getdate()) FOR [Last_Refreshed]
GO
ALTER TABLE [dbo].[T_DMS_Cached_Data_Status] ADD  CONSTRAINT [DF_T_DMS_Cached_Data_Status_Last_Full_Refresh]  DEFAULT (getdate()) FOR [Last_Full_Refresh]
GO
