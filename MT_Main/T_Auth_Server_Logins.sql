/****** Object:  Table [dbo].[T_Auth_Server_Logins] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Auth_Server_Logins](
	[LoginName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[User_Type_Desc] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Server_Roles] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Principal_ID] [int] NULL,
	[Entered] [datetime] NULL,
	[Last_Affected] [datetime] NULL,
	[Enabled] [tinyint] NOT NULL,
 CONSTRAINT [PK_T_Auth_Server_Logins] PRIMARY KEY CLUSTERED 
(
	[LoginName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Auth_Server_Logins] ADD  CONSTRAINT [DF_T_Auth_Server_Logins_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
ALTER TABLE [dbo].[T_Auth_Server_Logins] ADD  CONSTRAINT [DF_T_Auth_Server_Logins_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
ALTER TABLE [dbo].[T_Auth_Server_Logins] ADD  CONSTRAINT [DF_T_Auth_Server_Logins_Enabled]  DEFAULT ((1)) FOR [Enabled]
GO
