/****** Object:  Table [dbo].[T_MTS_Protein_DBs]    Script Date: 08/14/2006 20:23:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_MTS_Protein_DBs](
	[Protein_DB_ID] [int] NOT NULL,
	[Protein_DB_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Server_ID] [int] NOT NULL,
	[State_ID] [int] NOT NULL,
	[Last_Affected] [datetime] NOT NULL CONSTRAINT [DF_T_MTS_Protein_DBs_Last_Affected]  DEFAULT (getdate()),
	[DB_Schema_Version] [real] NOT NULL CONSTRAINT [DF_T_MTS_Protein_DBs_DB_Schema_Version]  DEFAULT (1),
	[Comment] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_MTS_Protein_DBs_Comment]  DEFAULT (''),
 CONSTRAINT [PK_T_MTS_Protein_DBs] PRIMARY KEY CLUSTERED 
(
	[Protein_DB_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_MTS_Protein_DBs]    Script Date: 08/14/2006 20:23:00 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_MTS_Protein_DBs] ON [dbo].[T_MTS_Protein_DBs] 
(
	[Protein_DB_Name] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_MTS_Protein_DBs]  WITH NOCHECK ADD  CONSTRAINT [FK_T_MTS_Protein_DBs_T_MTS_Servers] FOREIGN KEY([Server_ID])
REFERENCES [T_MTS_Servers] ([Server_ID])
GO
ALTER TABLE [dbo].[T_MTS_Protein_DBs] CHECK CONSTRAINT [FK_T_MTS_Protein_DBs_T_MTS_Servers]
GO
