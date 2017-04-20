/****** Object:  Table [dbo].[T_Database_Backups] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Database_Backups](
	[Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Full_Backup_Interval_Days] [float] NOT NULL,
	[Last_Full_Backup] [datetime] NULL,
	[Last_Trans_Backup] [datetime] NULL,
	[Last_Failed_Backup] [datetime] NULL,
	[Failed_Backup_Message] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Database_Backups] PRIMARY KEY CLUSTERED 
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_Database_Backups] ADD  CONSTRAINT [DF_T_Database_Backups_Full_Backup_Interval_Days]  DEFAULT ((14)) FOR [Full_Backup_Interval_Days]
GO
