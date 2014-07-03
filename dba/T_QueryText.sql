/****** Object:  Table [dbo].[T_QueryText] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_QueryText](
	[sql_handle] [varbinary](64) NOT NULL,
	[QueryText] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DatabaseName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[objtype] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entered] [datetime] NOT NULL,
 CONSTRAINT [PK_T_QueryText] PRIMARY KEY CLUSTERED 
(
	[sql_handle] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_QueryText] ADD  CONSTRAINT [DF_T_QueryText_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
