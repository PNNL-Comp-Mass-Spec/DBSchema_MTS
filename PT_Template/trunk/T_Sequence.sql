/****** Object:  Table [dbo].[T_Sequence] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Sequence](
	[Seq_ID] [int] NOT NULL,
	[Clean_Sequence] [varchar](850) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Mod_Count] [smallint] NULL,
	[Mod_Description] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Monoisotopic_Mass] [float] NULL,
	[GANET_Predicted] [real] NULL,
	[Cleavage_State_Max] [tinyint] NOT NULL CONSTRAINT [DF_T_Sequence_Cleavage_State_Max]  DEFAULT (0),
 CONSTRAINT [PK_T_Sequence] PRIMARY KEY NONCLUSTERED 
(
	[Seq_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Sequence] ******/
CREATE NONCLUSTERED INDEX [IX_T_Sequence] ON [dbo].[T_Sequence] 
(
	[Clean_Sequence] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Sequence_ModCount] ******/
CREATE NONCLUSTERED INDEX [IX_T_Sequence_ModCount] ON [dbo].[T_Sequence] 
(
	[Mod_Count] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Sequence_Monoisotopic_Mass] ******/
CREATE NONCLUSTERED INDEX [IX_T_Sequence_Monoisotopic_Mass] ON [dbo].[T_Sequence] 
(
	[Monoisotopic_Mass] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Sequence_Seq_ID_Cleavage_State_Max] ******/
CREATE NONCLUSTERED INDEX [IX_T_Sequence_Seq_ID_Cleavage_State_Max] ON [dbo].[T_Sequence] 
(
	[Seq_ID] ASC,
	[Cleavage_State_Max] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Sequence_Seq_ID_Monoisotopic_Mass] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Sequence_Seq_ID_Monoisotopic_Mass] ON [dbo].[T_Sequence] 
(
	[Seq_ID] ASC,
	[Monoisotopic_Mass] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO
