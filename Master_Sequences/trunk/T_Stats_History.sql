/****** Object:  Table [dbo].[T_Stats_History] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Stats_History](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Posting_Time] [datetime] NOT NULL CONSTRAINT [DF_T_Stats_History_Posting_Time]  DEFAULT (getdate()),
	[Sequence_Count] [int] NOT NULL,
 CONSTRAINT [PK_T_Stats_History] PRIMARY KEY NONCLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Stats_History] ******/
CREATE UNIQUE CLUSTERED INDEX [IX_T_Stats_History] ON [dbo].[T_Stats_History] 
(
	[Posting_Time] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO
