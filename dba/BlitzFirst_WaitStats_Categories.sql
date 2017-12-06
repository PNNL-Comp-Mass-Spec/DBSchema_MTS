/****** Object:  Table [dbo].[BlitzFirst_WaitStats_Categories] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BlitzFirst_WaitStats_Categories](
	[WaitType] [nvarchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[WaitCategory] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Ignorable] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[WaitType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[BlitzFirst_WaitStats_Categories] ADD  DEFAULT ((0)) FOR [Ignorable]
GO
