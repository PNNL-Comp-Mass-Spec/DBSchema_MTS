/****** Object:  Table [dbo].[QueryHistory] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[QueryHistory](
	[QueryHistoryID] [int] IDENTITY(1,1) NOT NULL,
	[Collection_Time] [datetime] NOT NULL,
	[Start_Time] [datetime] NOT NULL,
	[Login_Time] [datetime] NULL,
	[Session_ID] [smallint] NOT NULL,
	[CPU] [int] NULL,
	[Reads] [bigint] NULL,
	[Writes] [bigint] NULL,
	[Physical_Reads] [bigint] NULL,
	[Host_Name] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Database_Name] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Login_Name] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[SQL_Text] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Program_Name] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [pk_QueryHistory] PRIMARY KEY CLUSTERED 
(
	[QueryHistoryID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
