/****** Object:  Table [dbo].[T_Analysis_Task_Cache_Update_State_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Task_Cache_Update_State_Name](
	[Cache_Update_State] [int] NOT NULL,
	[Cache_Update_State_Name] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Analysis_Task_Cache_Update_State_Name] PRIMARY KEY CLUSTERED 
(
	[Cache_Update_State] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
