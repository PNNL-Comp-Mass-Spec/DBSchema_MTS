/****** Object:  Table [dbo].[T_SP_Categories] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_SP_Categories](
	[Category_ID] [int] NOT NULL,
	[Category_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_SP_Categories] PRIMARY KEY CLUSTERED 
(
	[Category_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
