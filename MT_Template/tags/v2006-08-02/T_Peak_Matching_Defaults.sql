if exists (select * from dbo.sysobjects where id = object_id(N'[T_Peak_Matching_Defaults]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Peak_Matching_Defaults]
GO

CREATE TABLE [T_Peak_Matching_Defaults] (
	[Default_ID] [int] IDENTITY (100, 1) NOT NULL ,
	[Instrument_Name] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
	[Dataset_Name_Filter] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Labelling_Filter] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[IniFile_Name] [varchar] (185) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[Confirmed_Only] [tinyint] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Defaults_Confirmed_Only] DEFAULT (0),
	[Mod_List] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_Peak_Matching_Defaults_Mod_List] DEFAULT (''),
	[Minimum_High_Normalized_Score] [real] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Defaults_Minimum_High_Normalized_Score] DEFAULT (1.0),
	[Minimum_High_Discriminant_Score] [real] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Defaults_Minimum_High_Discriminant_Score] DEFAULT (0),
	[Minimum_PMT_Quality_Score] [decimal](9, 5) NOT NULL CONSTRAINT [DF_T_Peak_Matching_Defaults_Minimum_PMT_Quality_Score] DEFAULT (1),
	[Priority] [int] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Defaults_Priority] DEFAULT (5),
	CONSTRAINT [PK_T_Peak_Matching_Defaults] PRIMARY KEY  CLUSTERED 
	(
		[Default_ID]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] 
) ON [PRIMARY]
GO


