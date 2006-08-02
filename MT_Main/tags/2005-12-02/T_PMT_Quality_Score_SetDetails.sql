if exists (select * from dbo.sysobjects where id = object_id(N'[T_PMT_Quality_Score_SetDetails]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_PMT_Quality_Score_SetDetails]
GO

CREATE TABLE [T_PMT_Quality_Score_SetDetails] (
	[PMT_Quality_Score_Set_ID] [int] NOT NULL ,
	[Evaluation_Order] [tinyint] NOT NULL ,
	[Analysis_Count_Comparison] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_Parameters_Analysis_Count_Comparison] DEFAULT ('>='),
	[Analysis_Count_Threshold] [smallint] NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_Parameters_Analysis_Count_Threshold] DEFAULT (1),
	[Charge_State_Comparison] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_Parameters_Charge_State_Comparison] DEFAULT ('='),
	[Charge_State_Threshold] [tinyint] NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_Parameters_Charge_State_Threshold] DEFAULT (1),
	[High_Normalized_Score_Comparison] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_Parameters_High_Normalized_Score_Comparison] DEFAULT ('>='),
	[High_Normalized_Score_Threshold] [float] NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_Parameters_High_Normalized_Score_Threshold] DEFAULT (2),
	[Cleavage_State_Comparison] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_Parameters_Cleavage_State_Comparison] DEFAULT ('>='),
	[Cleavage_State_Threshold] [tinyint] NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_Parameters_Cleaveage_State_Threshold] DEFAULT (0),
	[Peptide_Length_Comparison] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_SetDetails_Peptide_Length_Comparison] DEFAULT ('>='),
	[Peptide_Length_Threshold] [smallint] NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_SetDetails_Peptide_Length_Threshold] DEFAULT (6),
	[Mass_Comparison] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_SetDetails_Mass_Comparison] DEFAULT ('>='),
	[Mass_Threshold] [decimal](9, 4) NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_SetDetails_Mass_Threshold] DEFAULT (0),
	[DelCN_Comparison] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_SetDetails_DelCN_Comparison] DEFAULT ('<='),
	[DelCN_Threshold] [decimal](9, 5) NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_SetDetails_DelCN_Threshold] DEFAULT (1),
	[DelCN2_Comparison] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_SetDetails_DelCN2_Comparison] DEFAULT ('>='),
	[DelCN2_Threshold] [decimal](9, 5) NOT NULL CONSTRAINT [DF_T_PMT_Quality_Score_SetDetails_DelCN2_Threshold] DEFAULT (0),
	CONSTRAINT [PK_T_PMT_Quality_Score_Parameters] PRIMARY KEY  CLUSTERED 
	(
		[PMT_Quality_Score_Set_ID],
		[Evaluation_Order]
	) WITH  FILLFACTOR = 90  ON [PRIMARY] ,
	CONSTRAINT [FK_T_PMT_Quality_Score_Parameters_T_PMT_Quality_Score_Sets] FOREIGN KEY 
	(
		[PMT_Quality_Score_Set_ID]
	) REFERENCES [T_PMT_Quality_Score_Sets] (
		[PMT_Quality_Score_Set_ID]
	) ON UPDATE CASCADE ,
	CONSTRAINT [CK_T_PMT_Quality_Score_Parameters_Analysis_Count_Comparison] CHECK ([Analysis_Count_Comparison] = '<=' or ([Analysis_Count_Comparison] = '>=' or ([Analysis_Count_Comparison] = '<' or ([Analysis_Count_Comparison] = '=' or [Analysis_Count_Comparison] = '>')))),
	CONSTRAINT [CK_T_PMT_Quality_Score_Parameters_Charge_State_Comparison] CHECK ([Charge_State_Comparison] = '<=' or ([Charge_State_Comparison] = '>=' or ([Charge_State_Comparison] = '<' or ([Charge_State_Comparison] = '=' or [Charge_State_Comparison] = '>')))),
	CONSTRAINT [CK_T_PMT_Quality_Score_Parameters_Cleavage_State_Comparison] CHECK ([Cleavage_State_Comparison] = '<=' or ([Cleavage_State_Comparison] = '>=' or ([Cleavage_State_Comparison] = '<' or ([Cleavage_State_Comparison] = '=' or [Cleavage_State_Comparison] = '>')))),
	CONSTRAINT [CK_T_PMT_Quality_Score_Parameters_DelCN] CHECK ([DelCN_Comparison] = '>=' or [DelCN_Comparison] = '>' or [DelCN_Comparison] = '<=' or [DelCN_Comparison] = '<' or [DelCN_Comparison] = '='),
	CONSTRAINT [CK_T_PMT_Quality_Score_Parameters_DelCN2] CHECK ([DelCN2_Comparison] = '>=' or [DelCN2_Comparison] = '>' or [DelCN2_Comparison] = '<=' or [DelCN2_Comparison] = '<' or [DelCN2_Comparison] = '='),
	CONSTRAINT [CK_T_PMT_Quality_Score_Parameters_High_Score_Comparison] CHECK ([High_Normalized_Score_Comparison] = '<=' or ([High_Normalized_Score_Comparison] = '>=' or ([High_Normalized_Score_Comparison] = '<' or ([High_Normalized_Score_Comparison] = '=' or [High_Normalized_Score_Comparison] = '>')))),
	CONSTRAINT [CK_T_PMT_Quality_Score_Parameters_Mass] CHECK ([Mass_Comparison] = '<=' or [Mass_Comparison] = '<' or [Mass_Comparison] = '>=' or [Mass_Comparison] = '>=' or [Mass_Comparison] = '=')
) ON [PRIMARY]
GO


