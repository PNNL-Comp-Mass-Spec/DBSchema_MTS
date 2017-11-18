/****** Object:  Table [dbo].[T_Analysis_Task_Candidate_DBs] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Task_Candidate_DBs](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Tool_ID] [int] NOT NULL,
	[Server_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Database_Name] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Task_Count_Total] [int] NULL,
	[Task_Count_New] [int] NULL,
	[Task_Count_Processing] [int] NULL,
	[Last_Affected] [datetime] NOT NULL,
	[Last_NewTask_Date] [datetime] NULL,
	[Last_Processing_Date] [datetime] NULL,
 CONSTRAINT [PK_T_Analysis_Task_Candidate_DBs] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_Analysis_Task_Candidate_DBs_Tool_ID] ******/
CREATE NONCLUSTERED INDEX [IX_T_Analysis_Task_Candidate_DBs_Tool_ID] ON [dbo].[T_Analysis_Task_Candidate_DBs]
(
	[Tool_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_T_Analysis_Task_Candidate_DBs_Tool_Server_DB] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Analysis_Task_Candidate_DBs_Tool_Server_DB] ON [dbo].[T_Analysis_Task_Candidate_DBs]
(
	[Tool_ID] ASC,
	[Server_Name] ASC,
	[Database_Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Analysis_Task_Candidate_DBs] ADD  CONSTRAINT [DF_T_Analysis_Task_Candidate_DBs_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
ALTER TABLE [dbo].[T_Analysis_Task_Candidate_DBs]  WITH CHECK ADD  CONSTRAINT [FK_T_Analysis_Task_Candidate_DBs_T_Analysis_Tool] FOREIGN KEY([Tool_ID])
REFERENCES [dbo].[T_Analysis_Tool] ([Tool_ID])
GO
ALTER TABLE [dbo].[T_Analysis_Task_Candidate_DBs] CHECK CONSTRAINT [FK_T_Analysis_Task_Candidate_DBs_T_Analysis_Tool]
GO
