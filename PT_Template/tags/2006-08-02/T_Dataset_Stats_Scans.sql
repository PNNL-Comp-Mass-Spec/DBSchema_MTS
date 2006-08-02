if exists (select * from dbo.sysobjects where id = object_id(N'[T_Dataset_Stats_Scans]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Dataset_Stats_Scans]
GO

CREATE TABLE [T_Dataset_Stats_Scans] (
	[Job] [int] NOT NULL ,
	[Scan_Number] [int] NOT NULL ,
	[Scan_Time] [real] NULL ,
	[Scan_Type] [tinyint] NULL ,
	[Total_Ion_Intensity] [float] NULL ,
	[Base_Peak_Intensity] [float] NULL ,
	[Base_Peak_MZ] [float] NULL ,
	[Base_Peak_SN_Ratio] [real] NULL ,
	CONSTRAINT [PK_T_Dataset_Stats_Scans] PRIMARY KEY  CLUSTERED 
	(
		[Job],
		[Scan_Number]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Dataset_Stats_Scans_T_Analysis_Description] FOREIGN KEY 
	(
		[Job]
	) REFERENCES [T_Analysis_Description] (
		[Job]
	),
	CONSTRAINT [FK_T_Dataset_Stats_Scans_T_Dataset_Scan_Type_Name] FOREIGN KEY 
	(
		[Scan_Type]
	) REFERENCES [T_Dataset_Scan_Type_Name] (
		[Scan_Type]
	)
) ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_Dataset_Stats_Scans_MZ] ON [T_Dataset_Stats_Scans]([Base_Peak_MZ]) ON [PRIMARY]
GO


