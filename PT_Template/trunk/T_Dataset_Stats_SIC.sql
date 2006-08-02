if exists (select * from dbo.sysobjects where id = object_id(N'[T_Dataset_Stats_SIC]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Dataset_Stats_SIC]
GO

CREATE TABLE [T_Dataset_Stats_SIC] (
	[Job] [int] NOT NULL ,
	[Parent_Ion_Index] [int] NOT NULL ,
	[MZ] [float] NULL ,
	[Survey_Scan_Number] [int] NULL ,
	[Frag_Scan_Number] [int] NOT NULL ,
	[Optimal_Peak_Apex_Scan_Number] [int] NULL ,
	[Peak_Apex_Override_Parent_Ion_Index] [int] NULL ,
	[Custom_SIC_Peak] [tinyint] NULL ,
	[Peak_Scan_Start] [int] NULL ,
	[Peak_Scan_End] [int] NULL ,
	[Peak_Scan_Max_Intensity] [int] NULL ,
	[Peak_Intensity] [float] NULL ,
	[Peak_SN_Ratio] [real] NULL ,
	[FWHM_In_Scans] [int] NULL ,
	[Peak_Area] [float] NULL ,
	[Parent_Ion_Intensity] [real] NULL ,
	[Peak_Baseline_Noise_Level] [real] NULL ,
	[Peak_Baseline_Noise_StDev] [real] NULL ,
	[Peak_Baseline_Points_Used] [smallint] NULL ,
	[StatMoments_Area] [real] NULL ,
	[CenterOfMass_Scan] [int] NULL ,
	[Peak_StDev] [real] NULL ,
	[Peak_Skew] [real] NULL ,
	[Peak_KSStat] [real] NULL ,
	[StatMoments_DataCount_Used] [smallint] NULL ,
	CONSTRAINT [PK_T_Dataset_Stats_SIC] PRIMARY KEY  CLUSTERED 
	(
		[Job],
		[Parent_Ion_Index],
		[Frag_Scan_Number]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Dataset_Stats_SIC_T_Analysis_Description] FOREIGN KEY 
	(
		[Job]
	) REFERENCES [T_Analysis_Description] (
		[Job]
	)
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Dataset_Stats_SIC_MZ] ON [T_Dataset_Stats_SIC]([MZ]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Dataset_Stats_SIC_FragScan_Job_OptimalPeakApex] ON [T_Dataset_Stats_SIC]([Frag_Scan_Number], [Job], [Optimal_Peak_Apex_Scan_Number]) ON [PRIMARY]
GO


