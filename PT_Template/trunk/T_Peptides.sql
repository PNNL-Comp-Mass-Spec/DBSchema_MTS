/****** Object:  Table [dbo].[T_Peptides] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peptides](
	[Peptide_ID] [int] IDENTITY(1000,1) NOT NULL,
	[Analysis_ID] [int] NOT NULL,
	[Scan_Number] [int] NULL,
	[Number_Of_Scans] [smallint] NULL,
	[Charge_State] [smallint] NULL,
	[MH] [float] NULL,
	[Multiple_ORF] [int] NULL,
	[Peptide] [varchar](850) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Seq_ID] [int] NULL,
	[GANET_Obs] [real] NULL,
	[Scan_Time_Peak_Apex] [real] NULL,
	[Peak_Area] [real] NULL,
	[Peak_SN_Ratio] [real] NULL,
	[Max_Obs_Area_In_Job] [tinyint] NOT NULL CONSTRAINT [DF_T_Peptides_Max_Obs_Area_In_Job]  DEFAULT (0),
 CONSTRAINT [PK_T_Peptides] PRIMARY KEY NONCLUSTERED 
(
	[Peptide_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Peptides_AnalysisID_PeptideID] ******/
CREATE CLUSTERED INDEX [IX_T_Peptides_AnalysisID_PeptideID] ON [dbo].[T_Peptides] 
(
	[Analysis_ID] ASC,
	[Peptide_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Peptides_Scan_Number] ******/
CREATE NONCLUSTERED INDEX [IX_T_Peptides_Scan_Number] ON [dbo].[T_Peptides] 
(
	[Scan_Number] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_Peptides_Seq_ID] ******/
CREATE NONCLUSTERED INDEX [IX_T_Peptides_Seq_ID] ON [dbo].[T_Peptides] 
(
	[Seq_ID] ASC
)WITH (PAD_INDEX  = OFF, IGNORE_DUP_KEY = OFF, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Peptides]  WITH NOCHECK ADD  CONSTRAINT [FK_T_Peptides_T_Analysis_Description] FOREIGN KEY([Analysis_ID])
REFERENCES [T_Analysis_Description] ([Job])
GO
ALTER TABLE [dbo].[T_Peptides] CHECK CONSTRAINT [FK_T_Peptides_T_Analysis_Description]
GO
ALTER TABLE [dbo].[T_Peptides]  WITH CHECK ADD  CONSTRAINT [FK_T_Peptides_T_Sequence] FOREIGN KEY([Seq_ID])
REFERENCES [T_Sequence] ([Seq_ID])
GO
ALTER TABLE [dbo].[T_Peptides] CHECK CONSTRAINT [FK_T_Peptides_T_Sequence]
GO
