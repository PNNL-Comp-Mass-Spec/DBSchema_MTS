if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peptides]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peptides]
GO

CREATE TABLE [T_Peptides] (
	[Peptide_ID] [int] NOT NULL ,
	[Analysis_ID] [int] NOT NULL ,
	[Scan_Number] [int] NULL ,
	[Number_Of_Scans] [smallint] NULL ,
	[Charge_State] [smallint] NULL ,
	[MH] [float] NULL ,
	[Multiple_Proteins] [smallint] NULL ,
	[Peptide] [varchar] (850) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Mass_Tag_ID] [int] NOT NULL ,
	[GANET_Obs] [real] NULL ,
	[State_ID] [tinyint] NOT NULL CONSTRAINT [DF_T_Peptides_State] DEFAULT (1),
	[Scan_Time_Peak_Apex] [real] NULL ,
	[Peak_Area] [real] NULL ,
	[Peak_SN_Ratio] [real] NULL ,
	[Max_Obs_Area_In_Job] [tinyint] NOT NULL CONSTRAINT [DF_T_Peptides_Max_Obs_Area_In_Job] DEFAULT (0),
	CONSTRAINT [PK_T_Peptides] PRIMARY KEY  CLUSTERED 
	(
		[Peptide_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Peptides_T_Analysis_Description] FOREIGN KEY 
	(
		[Analysis_ID]
	) REFERENCES [T_Analysis_Description] (
		[Job]
	),
	CONSTRAINT [FK_T_Peptides_T_Mass_Tags] FOREIGN KEY 
	(
		[Mass_Tag_ID]
	) REFERENCES [T_Mass_Tags] (
		[Mass_Tag_ID]
	),
	CONSTRAINT [FK_T_Peptides_T_Peptide_State_Name] FOREIGN KEY 
	(
		[State_ID]
	) REFERENCES [T_Peptide_State_Name] (
		[State_ID]
	)
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Peptides_Mass_Tag_ID] ON [T_Peptides]([Mass_Tag_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Peptides_Analysis_ID] ON [T_Peptides]([Analysis_ID]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Peptides_Peptide] ON [T_Peptides]([Peptide]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Peptides_Analysis_ID_Mass_Tag_ID] ON [T_Peptides]([Analysis_ID], [Mass_Tag_ID]) ON [PRIMARY]
GO

/****** The index created by the following statement is for internal use only. ******/
/****** It is not a real index but exists as statistics only. ******/
if (@@microsoftversion > 0x07000000 )
EXEC ('CREATE STATISTICS [Statistic_Peak_Area] ON [T_Peptides] ([Peak_Area]) ')
GO


