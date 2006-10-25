/****** Object:  Table [dbo].[T_Proteins] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Proteins](
	[Ref_ID] [int] IDENTITY(100,1) NOT NULL,
	[Reference] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Proteins] PRIMARY KEY CLUSTERED 
(
	[Ref_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Proteins] ******/
CREATE NONCLUSTERED INDEX [IX_T_Proteins] ON [dbo].[T_Proteins] 
(
	[Reference] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO
