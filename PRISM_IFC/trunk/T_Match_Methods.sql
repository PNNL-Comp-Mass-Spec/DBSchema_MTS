/****** Object:  Table [dbo].[T_Match_Methods] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Match_Methods](
	[Match_Method_ID] [int] NOT NULL,
	[Name] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Internal_Code] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_Match_Mathods] PRIMARY KEY NONCLUSTERED 
(
	[Name] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Match_Methods] ******/
CREATE UNIQUE CLUSTERED INDEX [IX_T_Match_Methods] ON [dbo].[T_Match_Methods] 
(
	[Match_Method_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO
