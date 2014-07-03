/****** Object:  Table [dbo].[T_MTS_DB_Errors] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MTS_DB_Errors](
	[Entry_ID_Global] [int] IDENTITY(1,1) NOT NULL,
	[Server_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Database_Name] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Entry_ID] [int] NOT NULL,
	[Posted_By] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Posting_Time] [datetime] NOT NULL,
	[Type] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Message] [varchar](4096) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entered_By] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DB_Error_State] [tinyint] NOT NULL,
	[Last_Affected] [datetime] NOT NULL,
	[Ack_User] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_MTS_DB_Errors] PRIMARY KEY CLUSTERED 
(
	[Entry_ID_Global] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_MTS_DB_Errors] ADD  CONSTRAINT [DF_T_MTS_DB_Errors_DB_Error_State]  DEFAULT ((1)) FOR [DB_Error_State]
GO
ALTER TABLE [dbo].[T_MTS_DB_Errors] ADD  CONSTRAINT [DF_T_MTS_DB_Errors_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
