/****** Object:  Table [dbo].[T_DMS_Cached_Data_Status] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Cached_Data_Status](
	[Table_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Refresh_Count] [int] NOT NULL CONSTRAINT [DF_T_DMS_Cached_Data_Status_Refresh_Count]  DEFAULT ((0)),
	[Insert_Count] [int] NOT NULL CONSTRAINT [DF_T_DMS_Cached_Data_Status_Insert_Count]  DEFAULT ((0)),
	[Update_Count] [int] NOT NULL CONSTRAINT [DF_T_DMS_Cached_Data_Status_Update_Count]  DEFAULT ((0)),
	[Delete_Count] [int] NOT NULL CONSTRAINT [DF_T_DMS_Cached_Data_Status_Delete_Count]  DEFAULT ((0)),
	[Last_Refreshed] [datetime] NOT NULL CONSTRAINT [DF_T_DMS_Cached_Data_Status_Last_Refreshed]  DEFAULT (getdate()),
 CONSTRAINT [PK_T_DMS_Cached_Data_Status] PRIMARY KEY CLUSTERED 
(
	[Table_Name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
