/****** Object:  Table [dbo].[T_Candidate_Seq_Processing_Queue_State_Name] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Candidate_Seq_Processing_Queue_State_Name](
	[Queue_State] [smallint] NOT NULL,
	[Queue_State_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_Candidate_Seq_Processing_Queue_State_Name] PRIMARY KEY CLUSTERED 
(
	[Queue_State] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
