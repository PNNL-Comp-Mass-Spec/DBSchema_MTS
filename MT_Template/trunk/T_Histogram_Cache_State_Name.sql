/****** Object:  Table [dbo].[T_Histogram_Cache_State_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Histogram_Cache_State_Name](
	[Histogram_Cache_State] [smallint] NOT NULL,
	[Histogram_Cache_State_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Histogram_Cache_State_Name] PRIMARY KEY CLUSTERED 
(
	[Histogram_Cache_State] ASC
) ON [PRIMARY]
) ON [PRIMARY]

GO
