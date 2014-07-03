/****** Object:  Table [dbo].[T_General_Statistics] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_General_Statistics](
	[category] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[label] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[value] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[sequence] [int] IDENTITY(1000,1) NOT NULL,
 CONSTRAINT [PK_T_General_Statistics] PRIMARY KEY CLUSTERED 
(
	[sequence] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
