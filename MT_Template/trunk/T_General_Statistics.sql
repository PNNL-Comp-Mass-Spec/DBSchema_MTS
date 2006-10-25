/****** Object:  Table [dbo].[T_General_Statistics] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_General_Statistics](
	[Category] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Label] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Value] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Previous_Value] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entry_ID] [int] IDENTITY(1000,1) NOT NULL,
 CONSTRAINT [PK_T_General_Statistics] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO
