/****** Object:  Table [dbo].[AlertSettings] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AlertSettings](
	[AlertName] [nvarchar](25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[VariableName] [nvarchar](35) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Enabled] [bit] NULL,
	[Value] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Description] [nvarchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_AlertSettings] PRIMARY KEY CLUSTERED 
(
	[AlertName] ASC,
	[VariableName] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[AlertSettings] ADD  CONSTRAINT [df_AlertSettings_Enabled]  DEFAULT ((1)) FOR [Enabled]
GO
