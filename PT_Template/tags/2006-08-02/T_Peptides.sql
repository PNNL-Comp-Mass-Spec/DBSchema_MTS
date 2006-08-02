if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peptides]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peptides]
GO

CREATE TABLE [T_Peptides] (
	[Peptide_ID] [int] IDENTITY (1000, 1) NOT NULL ,
	[Analysis_ID] [int] NOT NULL ,
	[Scan_Number] [int] NULL ,
	[Number_Of_Scans] [smallint] NULL ,
	[Charge_State] [smallint] NULL ,
	[MH] [float] NULL ,
	[Multiple_ORF] [int] NULL ,
	[Peptide] [varchar] (850) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Seq_ID] [int] NULL ,
	[GANET_Obs] [real] NULL ,
	[Scan_Time_Peak_Apex] [real] NULL ,
	[Peak_Area] [real] NULL ,
	[Peak_SN_Ratio] [real] NULL ,
	[Max_Obs_Area_In_Job] [tinyint] NOT NULL CONSTRAINT [DF_T_Peptides_Max_Obs_Area_In_Job] DEFAULT (0),
	CONSTRAINT [PK_T_Peptides] PRIMARY KEY  NONCLUSTERED 
	(
		[Peptide_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Peptides_T_Analysis_Description] FOREIGN KEY 
	(
		[Analysis_ID]
	) REFERENCES [T_Analysis_Description] (
		[Job]
	),
	CONSTRAINT [FK_T_Peptides_T_Sequence] FOREIGN KEY 
	(
		[Seq_ID]
	) REFERENCES [T_Sequence] (
		[Seq_ID]
	)
) ON [PRIMARY]
GO

 CREATE  CLUSTERED  INDEX [IX_T_Peptides_AnalysisID_PeptideID] ON [T_Peptides]([Analysis_ID], [Peptide_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Peptides_Seq_ID] ON [T_Peptides]([Seq_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Peptides_Scan_Number] ON [T_Peptides]([Scan_Number]) ON [PRIMARY]
GO


