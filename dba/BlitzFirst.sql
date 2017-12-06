/****** Object:  Table [dbo].[BlitzFirst] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BlitzFirst](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ServerName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[CheckDate] [datetimeoffset](7) NULL,
	[CheckID] [int] NOT NULL,
	[Priority] [tinyint] NOT NULL,
	[FindingsGroup] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Finding] [varchar](200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[URL] [varchar](200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Details] [nvarchar](4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[HowToStopIt] [xml] NULL,
	[QueryPlan] [xml] NULL,
	[QueryText] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[StartTime] [datetimeoffset](7) NULL,
	[LoginName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[NTUserName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[OriginalLoginName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ProgramName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[HostName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DatabaseID] [int] NULL,
	[DatabaseName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[OpenTransactionCount] [int] NULL,
	[DetailsInt] [int] NULL,
 CONSTRAINT [PK_005C7C51-84E3-40C6-AB8A-0EA9470552CB] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
