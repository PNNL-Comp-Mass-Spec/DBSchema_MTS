/****** Object:  Table [dbo].[T_Peak_Matching_Stats_by_DB] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Peak_Matching_Stats_by_DB](
	[MTDB] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Job] [int] NOT NULL,
	[Dataset] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[MDID] [int] NOT NULL,
	[MD_Type_Name] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Ini_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MD_Peaks_Count] [int] NULL,
	[MD_Tool_Version] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[MD_Comparison_Mass_Tag_Count] [int] NOT NULL,
	[Minimum_High_Normalized_Score] [real] NOT NULL,
	[Minimum_High_Discriminant_Score] [real] NOT NULL,
	[Minimum_PMT_Quality_Score] [real] NOT NULL,
	[MD_NetAdj_NET_Min] [numeric](9, 5) NULL,
	[MD_NetAdj_NET_Max] [numeric](9, 5) NULL,
	[MD_MMA_TolerancePPM] [numeric](9, 4) NULL,
	[MD_NET_Tolerance] [numeric](9, 5) NULL,
	[Unique_PMTs_Matched] [int] NULL,
	[Mass_Error_Avg] [real] NULL,
	[Mass_Error_StDev] [real] NULL,
	[NET_Error_Avg] [real] NULL,
	[NET_Error_StDev] [real] NULL,
	[PM_Match_Score] [real] NULL,
	[Last_Affected] [datetime] NOT NULL CONSTRAINT [DF_T_Peak_Matching_Stats_by_DB_Last_Affected]  DEFAULT (getdate()),
 CONSTRAINT [PK_T_Peak_Matching_Stats_by_DB] PRIMARY KEY CLUSTERED 
(
	[MTDB] ASC,
	[Job] ASC,
	[MDID] ASC
) ON [PRIMARY]
) ON [PRIMARY]

GO
