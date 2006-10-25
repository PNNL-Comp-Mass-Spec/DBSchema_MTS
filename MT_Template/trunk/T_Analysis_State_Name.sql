/****** Object:  Table [dbo].[T_Analysis_State_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_State_Name](
	[AD_State_ID] [int] NOT NULL,
	[AD_State_Name] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Analysis_State_Name] PRIMARY KEY CLUSTERED 
(
	[AD_State_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
