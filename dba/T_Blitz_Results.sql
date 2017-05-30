/****** Object:  Table [dbo].[T_Blitz_Results] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Blitz_Results](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ServerName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[CheckDate] [datetimeoffset](7) NULL,
	[Priority] [tinyint] NULL,
	[FindingsGroup] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Finding] [varchar](200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DatabaseName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[URL] [varchar](200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Details] [nvarchar](4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[QueryPlan] [xml] NULL,
	[QueryPlanFiltered] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[CheckID] [int] NULL,
 CONSTRAINT [PK_1DCE21D4-E373-4B5B-82FD-2D3701A34914] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
