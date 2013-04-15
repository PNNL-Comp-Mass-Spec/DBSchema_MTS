/****** Object:  Table [dbo].[AlertSettings] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AlertSettings](
	[Name] [nvarchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[QueryValue] [int] NULL,
	[QueryValueDesc] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[QueryValue2] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[QueryValue2Desc] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[EmailList] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[EmailList2] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[CellList] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [pk_AlertSettings] PRIMARY KEY CLUSTERED 
(
	[Name] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
