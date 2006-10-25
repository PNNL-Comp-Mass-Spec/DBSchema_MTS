/****** Object:  Table [dbo].[T_ORF_Database_List] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_ORF_Database_List](
	[ODB_ID] [int] NOT NULL,
	[ODB_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ODB_Description] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_Organism] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_Connection_String] [varchar](1024) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_NetSQL_Conn_String] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_NetOleDB_Conn_String] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_State] [int] NOT NULL,
	[Notes] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ODB_Created] [smalldatetime] NOT NULL CONSTRAINT [DF_T_ORF_Database_List_ODB_Created]  DEFAULT (getdate()),
	[ODB_DB_Schema_Version] [real] NOT NULL CONSTRAINT [DF_T_ORF_Database_List_ODB_DB_Schema_Version]  DEFAULT (1),
	[ODB_Fasta_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_T_ORF_Database_List] PRIMARY KEY CLUSTERED 
(
	[ODB_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_ORF_Database_List] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_ORF_Database_List] ON [dbo].[T_ORF_Database_List] 
(
	[ODB_Name] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_ORF_Database_List]  WITH NOCHECK ADD  CONSTRAINT [FK_T_ORF_Database_List_T_MT_Database_State_Name] FOREIGN KEY([ODB_State])
REFERENCES [T_MT_Database_State_Name] ([ID])
GO
ALTER TABLE [dbo].[T_ORF_Database_List] CHECK CONSTRAINT [FK_T_ORF_Database_List_T_MT_Database_State_Name]
GO
