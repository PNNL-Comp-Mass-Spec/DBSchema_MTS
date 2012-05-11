/****** Object:  Table [dbo].[T_Analysis_ToolVersion] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_ToolVersion](
	[Job] [int] NOT NULL,
	[Tool_Version] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DataExtractor_Version] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MSGF_Version] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entered] [datetime] NULL,
	[Last_Affected] [datetime] NULL,
 CONSTRAINT [PK_T_Analysis_ToolVersion] PRIMARY KEY CLUSTERED 
(
	[Job] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Analysis_ToolVersion]  WITH CHECK ADD  CONSTRAINT [FK_T_Analysis_ToolVersion_T_Analysis_Description] FOREIGN KEY([Job])
REFERENCES [T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Analysis_ToolVersion] CHECK CONSTRAINT [FK_T_Analysis_ToolVersion_T_Analysis_Description]
GO
ALTER TABLE [dbo].[T_Analysis_ToolVersion] ADD  CONSTRAINT [DF_T_Analysis_ToolVersion_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
ALTER TABLE [dbo].[T_Analysis_ToolVersion] ADD  CONSTRAINT [DF_T_Analysis_ToolVersion_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
