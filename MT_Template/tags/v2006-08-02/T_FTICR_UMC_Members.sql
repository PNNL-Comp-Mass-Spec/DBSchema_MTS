if exists (select * from dbo.sysobjects where id = object_id(N'[T_FTICR_UMC_Members]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_FTICR_UMC_Members]
GO

CREATE TABLE [T_FTICR_UMC_Members] (
	[UMC_Members_ID] [int] IDENTITY (1, 1) NOT NULL ,
	[UMC_Results_ID] [int] NOT NULL ,
	[Member_Type_ID] [tinyint] NOT NULL ,
	[Index_in_UMC] [int] NOT NULL ,
	[Scan_Number] [int] NOT NULL ,
	[MZ] [float] NOT NULL ,
	[Charge_State] [smallint] NULL ,
	[Monoisotopic_Mass] [float] NULL ,
	[Abundance] [float] NULL ,
	[Isotopic_Fit] [real] NULL ,
	[Elution_Time] [real] NULL ,
	[Is_Charge_State_Rep] [tinyint] NULL ,
	CONSTRAINT [PK_T_FTICR_UMC_Members] PRIMARY KEY  NONCLUSTERED 
	(
		[UMC_Members_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_FTICR_UMC_Members_T_FPR_UMC_Member_Type_Name] FOREIGN KEY 
	(
		[Member_Type_ID]
	) REFERENCES [T_FPR_UMC_Member_Type_Name] (
		[Member_Type_ID]
	),
	CONSTRAINT [FK_T_FTICR_UMC_Members_T_FTICR_UMC_Results] FOREIGN KEY 
	(
		[UMC_Results_ID]
	) REFERENCES [T_FTICR_UMC_Results] (
		[UMC_Results_ID]
	)
) ON [PRIMARY]
GO

 CREATE  UNIQUE  CLUSTERED  INDEX [IX_T_FTICR_UMC_Members] ON [T_FTICR_UMC_Members]([UMC_Results_ID], [Index_in_UMC]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO

 CREATE  INDEX [IX_T_FTICR_UMC_Members_Monoisotopic_Mass] ON [T_FTICR_UMC_Members]([Monoisotopic_Mass]) WITH  FILLFACTOR = 90 ON [PRIMARY]
GO


