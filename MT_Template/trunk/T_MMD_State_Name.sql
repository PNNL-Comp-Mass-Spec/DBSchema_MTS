/****** Object:  Table [dbo].[T_MMD_State_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MMD_State_Name](
	[MD_State] [tinyint] IDENTITY(1,1) NOT NULL,
	[MD_State_Name] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_MMD_State_Name] PRIMARY KEY CLUSTERED 
(
	[MD_State] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
