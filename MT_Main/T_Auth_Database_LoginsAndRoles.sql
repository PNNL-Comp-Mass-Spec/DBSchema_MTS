/****** Object:  Table [dbo].[T_Auth_Database_LoginsAndRoles] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Auth_Database_LoginsAndRoles](
	[Database_ID] [int] NOT NULL,
	[Database_Name] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Principal_ID] [int] NOT NULL,
	[UserName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[LoginName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[User_Type] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[User_Type_Desc] [nvarchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Database_Roles] [nvarchar](2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entered] [datetime] NOT NULL,
	[Last_Affected] [datetime] NOT NULL,
	[Enabled] [tinyint] NOT NULL,
 CONSTRAINT [PK_T_Auth_Database_LoginsAndRoles] PRIMARY KEY CLUSTERED 
(
	[Database_ID] ASC,
	[Principal_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Auth_Database_LoginsAndRoles] ADD  CONSTRAINT [DF_T_Auth_Database_LoginsAndRoles_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
ALTER TABLE [dbo].[T_Auth_Database_LoginsAndRoles] ADD  CONSTRAINT [DF_T_Auth_Database_LoginsAndRoles_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
ALTER TABLE [dbo].[T_Auth_Database_LoginsAndRoles] ADD  CONSTRAINT [DF_T_Auth_Database_LoginsAndRoles_Enabled]  DEFAULT ((1)) FOR [Enabled]
GO
