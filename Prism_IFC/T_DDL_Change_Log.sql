/****** Object:  Table [dbo].[T_DDL_Change_Log] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DDL_Change_Log](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Entered] [datetime] NOT NULL,
	[Entered_By] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[UserName] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Login_Name] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Event_Type] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Object] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Object_Type] [nvarchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[tsql] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_DDL_Change_Log] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_DDL_Change_Log] ADD  CONSTRAINT [DF_ddl_log_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
ALTER TABLE [dbo].[T_DDL_Change_Log] ADD  CONSTRAINT [DF_T_DDL_Change_Log_Entered_By]  DEFAULT (CONVERT([nvarchar](256),suser_sname(),(0))) FOR [Entered_By]
GO
ALTER TABLE [dbo].[T_DDL_Change_Log] ADD  CONSTRAINT [DF_ddl_log_UserName]  DEFAULT (CONVERT([nvarchar](256),user_name(),(0))) FOR [UserName]
GO
ALTER TABLE [dbo].[T_DDL_Change_Log] ADD  CONSTRAINT [DF_T_DDL_Change_Log_Login_Name]  DEFAULT (CONVERT([nvarchar](256),original_login(),(0))) FOR [Login_Name]
GO
