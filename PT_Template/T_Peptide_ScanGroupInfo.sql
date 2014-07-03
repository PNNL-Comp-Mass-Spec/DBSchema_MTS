/****** Object:  Table [dbo].[T_Peptide_ScanGroupInfo] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peptide_ScanGroupInfo](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Job] [int] NOT NULL,
	[Scan_Group_ID] [int] NOT NULL,
	[Charge] [smallint] NOT NULL,
	[Scan] [int] NOT NULL,
 CONSTRAINT [PK_T_Peptide_ScanGroupInfo] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Index [IX_T_Peptide_ScanGroupInfo_JobChargeScan] ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_T_Peptide_ScanGroupInfo_JobChargeScan] ON [dbo].[T_Peptide_ScanGroupInfo]
(
	[Job] ASC,
	[Charge] ASC,
	[Scan] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Peptide_ScanGroupInfo]  WITH CHECK ADD  CONSTRAINT [FK_T_Peptide_ScanGroupInfo_T_Analysis_Description] FOREIGN KEY([Job])
REFERENCES [dbo].[T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Peptide_ScanGroupInfo] CHECK CONSTRAINT [FK_T_Peptide_ScanGroupInfo_T_Analysis_Description]
GO
