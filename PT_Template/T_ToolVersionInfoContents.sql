/****** Object:  Table [dbo].[T_ToolVersionInfoContents] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_ToolVersionInfoContents](
	[EntryID] [int] IDENTITY(1,1) NOT NULL,
	[Data] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Entered] [datetime] NOT NULL,
 CONSTRAINT [PK_T_ToolVersionInfoContents] PRIMARY KEY CLUSTERED 
(
	[EntryID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_ToolVersionInfoContents] ADD  CONSTRAINT [DF_T_ToolVersionInfoContents_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
