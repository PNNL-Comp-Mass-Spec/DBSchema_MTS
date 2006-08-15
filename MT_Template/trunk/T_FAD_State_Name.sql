/****** Object:  Table [dbo].[T_FAD_State_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_FAD_State_Name](
	[FAD_State_ID] [int] NOT NULL,
	[FAD_State_Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_FTICR_Analysis_State_Name] PRIMARY KEY CLUSTERED 
(
	[FAD_State_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
