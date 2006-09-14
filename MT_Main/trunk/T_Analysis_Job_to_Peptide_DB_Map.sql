/****** Object:  Table [dbo].[T_Analysis_Job_to_Peptide_DB_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Job_to_Peptide_DB_Map](
	[Job] [int] NOT NULL,
	[PDB_ID] [int] NOT NULL,
	[ResultType] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Created] [datetime] NOT NULL,
	[Last_Affected] [datetime] NOT NULL CONSTRAINT [DF_T_Analysis_Job_to_Peptide_DB_Map_Last_Affected]  DEFAULT (getdate()),
	[Process_State] [int] NOT NULL,
 CONSTRAINT [PK_T_Analysis_Job_to_Peptide_DB_Map] PRIMARY KEY CLUSTERED 
(
	[Job] ASC,
	[PDB_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Analysis_Job_to_Peptide_DB_Map] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Analysis_Job_to_Peptide_DB_Map] ON [dbo].[T_Analysis_Job_to_Peptide_DB_Map] 
(
	[PDB_ID] ASC,
	[Job] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Analysis_Job_to_Peptide_DB_Map]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Analysis_Job_to_Peptide_DB_Map_T_Peptide_Database_List] FOREIGN KEY([PDB_ID])
REFERENCES [T_Peptide_Database_List] ([PDB_ID])
GO
ALTER TABLE [dbo].[T_Analysis_Job_to_Peptide_DB_Map] CHECK CONSTRAINT [FK_T_Analysis_Job_to_Peptide_DB_Map_T_Peptide_Database_List]
GO
