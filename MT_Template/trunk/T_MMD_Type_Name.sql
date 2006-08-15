/****** Object:  Table [dbo].[T_MMD_Type_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MMD_Type_Name](
	[MD_Type] [int] NOT NULL,
	[MD_Type_Name] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_MM_TypeName] PRIMARY KEY CLUSTERED 
(
	[MD_Type] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
