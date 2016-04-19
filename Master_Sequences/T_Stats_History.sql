/****** Object:  Table [dbo].[T_Stats_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Stats_History](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Posting_Time] [datetime] NOT NULL,
	[Sequence_Count] [int] NOT NULL,
 CONSTRAINT [PK_T_Stats_History] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_Stats_History] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Stats_History] ON [dbo].[T_Stats_History]
(
	[Posting_Time] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Stats_History] ADD  CONSTRAINT [DF_T_Stats_History_Posting_Time]  DEFAULT (getdate()) FOR [Posting_Time]
GO
