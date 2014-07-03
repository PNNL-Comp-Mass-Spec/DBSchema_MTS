/****** Object:  Table [dbo].[T_Candidate_Seq_Processing_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Candidate_Seq_Processing_History](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Source_Database] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Source_Job] [int] NULL,
	[Candidate_Seqs_Table_Name] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Queue_State] [smallint] NOT NULL,
	[Last_Affected] [datetime] NOT NULL,
	[Entered_Queue] [datetime] NOT NULL,
	[Sequence_Count] [int] NULL,
	[Sequence_Count_New] [int] NULL,
	[Processing_Start] [datetime] NULL,
	[Processing_Complete] [datetime] NULL,
	[Status_Message] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Candidate_Seq_Processing_History] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
GRANT INSERT ON [dbo].[T_Candidate_Seq_Processing_History] TO [DMS_SP_User] AS [dbo]
GO
GRANT UPDATE ON [dbo].[T_Candidate_Seq_Processing_History] TO [DMS_SP_User] AS [dbo]
GO
/****** Object:  Index [IX_T_Candidate_Seq_Processing_History] ******/
CREATE NONCLUSTERED INDEX [IX_T_Candidate_Seq_Processing_History] ON [dbo].[T_Candidate_Seq_Processing_History]
(
	[Queue_State] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Candidate_Seq_Processing_History] ADD  CONSTRAINT [DF_T_Candidate_Seq_Processing_History_Queue_State]  DEFAULT ((1)) FOR [Queue_State]
GO
ALTER TABLE [dbo].[T_Candidate_Seq_Processing_History] ADD  CONSTRAINT [DF_T_Candidate_Seq_Processing_History_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
ALTER TABLE [dbo].[T_Candidate_Seq_Processing_History] ADD  CONSTRAINT [DF_T_Candidate_Seq_Processing_History_Time_Queued]  DEFAULT (getdate()) FOR [Entered_Queue]
GO
ALTER TABLE [dbo].[T_Candidate_Seq_Processing_History] ADD  CONSTRAINT [DF_T_Candidate_Seq_Processing_History_Status_Message]  DEFAULT ('') FOR [Status_Message]
GO
ALTER TABLE [dbo].[T_Candidate_Seq_Processing_History]  WITH CHECK ADD  CONSTRAINT [FK_T_Candidate_Seq_Processing_History_T_Candidate_Seq_Processing_Queue_State_Name] FOREIGN KEY([Queue_State])
REFERENCES [dbo].[T_Candidate_Seq_Processing_Queue_State_Name] ([Queue_State])
GO
ALTER TABLE [dbo].[T_Candidate_Seq_Processing_History] CHECK CONSTRAINT [FK_T_Candidate_Seq_Processing_History_T_Candidate_Seq_Processing_Queue_State_Name]
GO
