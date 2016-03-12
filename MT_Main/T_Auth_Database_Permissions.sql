/****** Object:  Table [dbo].[T_Auth_Database_Permissions] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Auth_Database_Permissions](
	[Database_ID] [int] NOT NULL,
	[Database_Name] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Principal_ID] [int] NOT NULL,
	[Role_Or_User] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[User_Type] [char](1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[User_Type_Desc] [nvarchar](60) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Permission] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Object_Names] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Sort_Order] [int] NOT NULL,
	[Entered] [datetime] NOT NULL,
	[Last_Affected] [datetime] NOT NULL,
	[Enabled] [tinyint] NOT NULL,
 CONSTRAINT [PK_T_Auth_Database_Permissions] PRIMARY KEY CLUSTERED 
(
	[Database_ID] ASC,
	[Principal_ID] ASC,
	[Permission] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Auth_Database_Permissions] ADD  CONSTRAINT [DF_T_Auth_Database_Permissions_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
ALTER TABLE [dbo].[T_Auth_Database_Permissions] ADD  CONSTRAINT [DF_T_Auth_Database_Permissions_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
ALTER TABLE [dbo].[T_Auth_Database_Permissions] ADD  CONSTRAINT [DF_T_Auth_Database_Permissions_Enabled]  DEFAULT ((1)) FOR [Enabled]
GO
