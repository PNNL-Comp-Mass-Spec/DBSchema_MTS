/****** Object:  Table [dbo].[SchemaChangeLog] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SchemaChangeLog](
	[SchemaChangeLogID] [int] IDENTITY(1,1) NOT NULL,
	[CreateDate] [datetime] NULL,
	[LoginName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ComputerName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DBName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[SQLEvent] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Schema] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ObjectName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[SQLCmd] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[XmlEvent] [xml] NOT NULL,
 CONSTRAINT [PK_SchemaChangeLog] PRIMARY KEY CLUSTERED 
(
	[SchemaChangeLogID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
