/****** Object:  Table [dbo].[T_Usage_Stats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Usage_Stats](
	[Posted_By] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Last_Posting_Time] [datetime] NOT NULL CONSTRAINT [DF_T_Usage_Stats_Last_Posting_Time]  DEFAULT (getdate()),
	[Usage_Count] [int] NOT NULL CONSTRAINT [DF_T_Usage_Stats_Usage_Count]  DEFAULT (1),
 CONSTRAINT [PK_T_Usage_Stats] PRIMARY KEY CLUSTERED 
(
	[Posted_By] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
