/****** Object:  Table [dbo].[T_Current_Activity] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Current_Activity](
	[Database_ID] [int] NOT NULL,
	[Database_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Type] [char](4) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Update_Began] [datetime] NULL,
	[Update_Completed] [datetime] NULL,
	[Pause_Length_Minutes] [real] NOT NULL CONSTRAINT [DF_T_Current_Activity_Pause_Length_Minutes]  DEFAULT (0),
	[State] [int] NULL,
	[Comment] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Update_State] [int] NOT NULL CONSTRAINT [DF_T_Current_Activity_Update_State]  DEFAULT (0),
	[ET_Minutes_Last24Hours] [decimal](9, 2) NULL,
	[ET_Minutes_Last7Days] [decimal](9, 2) NULL,
 CONSTRAINT [PK_T_Current_Activity] PRIMARY KEY NONCLUSTERED 
(
	[Database_ID] ASC,
	[Type] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Current_Activity] ******/
CREATE CLUSTERED INDEX [IX_T_Current_Activity] ON [dbo].[T_Current_Activity] 
(
	[Database_Name] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Current_Activity]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Current_Activity_T_Update_State_Name] FOREIGN KEY([Update_State])
REFERENCES [T_Update_State_Name] ([ID])
GO
ALTER TABLE [dbo].[T_Current_Activity] CHECK CONSTRAINT [FK_T_Current_Activity_T_Update_State_Name]
GO
