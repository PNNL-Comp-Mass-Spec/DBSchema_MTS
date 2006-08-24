/****** Object:  Table [dbo].[T_SP_Glossary] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_SP_Glossary](
	[SP_ID] [int] NOT NULL,
	[Column_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Direction_ID] [int] NOT NULL,
	[Ordinal_Position] [smallint] NOT NULL,
	[Data_Type_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Field_Length] [int] NULL,
	[Description] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_SP_Glossary] PRIMARY KEY NONCLUSTERED 
(
	[SP_ID] ASC,
	[Column_Name] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_SP_Glossary] ******/
CREATE CLUSTERED INDEX [IX_T_SP_Glossary] ON [dbo].[T_SP_Glossary] 
(
	[SP_ID] ASC,
	[Direction_ID] ASC,
	[Ordinal_Position] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_SP_Glossary]  WITH CHECK ADD  CONSTRAINT [FK_T_SP_Glossary_T_SP_List] FOREIGN KEY([SP_ID])
REFERENCES [T_SP_List] ([SP_ID])
GO
ALTER TABLE [dbo].[T_SP_Glossary] CHECK CONSTRAINT [FK_T_SP_Glossary_T_SP_List]
GO
