/****** Object:  Table [dbo].[T_FPR_Type_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_FPR_Type_Name](
	[FPR_Type_ID] [int] NOT NULL,
	[FPR_Type_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_FPR_Type_Name] PRIMARY KEY CLUSTERED 
(
	[FPR_Type_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
